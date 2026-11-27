import Foundation

/// Decides when to record, using the same rules as the web app:
/// - measure the room for a few seconds, then keep tracking it as the quietest 10% of the last 60 seconds
///   (updated all the time, also while recording, so a fan turning on can't keep a recording going forever);
/// - start a clip when a sound is `sensitivity` dB louder than the room for at least a quarter of a second,
///   including the 3 seconds before it;
/// - end the clip after `silenceSeconds` without loud sounds, trimming the quiet tail
///   (a sound has to stay loud for ~0.2 s to restart that countdown, so single blips don't);
/// - remove rumble below ~80 Hz first: the iPhone app gets the raw mic, and deep rumble
///   (air handling, traffic, the building) would otherwise keep resetting the countdown;
/// - split clips at 20 minutes.
///
/// Not thread-safe: use it from one serial queue only (the recorder's audio queue).
/// Marked `@unchecked Sendable` because that queue is what keeps access safe.
final class Detector: @unchecked Sendable {
    enum Phase { case calibrating, listening, recording }

    struct Update {
        var level: Double
        var floor: Double?
        var trigger: Double?
        var phase: Phase
        /// While recording: seconds since the last loud sound (the stop countdown).
        var quietFor: Double?
    }

    struct FinishedClip {
        var start: Date
        var end: Date
        var peakDb: Double
        var samples: [Float]
        var sampleRate: Double
    }

    // Settings (may be changed while running, from the same queue).
    var sensitivity: Double
    var silenceSeconds: Double

    // Outputs.
    var onUpdate: ((Update) -> Void)?
    var onClip: ((FinishedClip) -> Void)?
    var onLevel: ((LevelSample) -> Void)?

    private let calibrationSeconds = 2.5
    private let prerollSeconds = 3.0
    private let tailSeconds = 4.0
    private let maxClipSeconds = 20.0 * 60
    private let triggerSeconds = 0.25
    private let floorWindow: TimeInterval = 60
    private let targetRate = 16000.0
    private let highPassHz = 80.0
    private let loudToResetSeconds = 0.2

    // High-pass filter (2nd-order Butterworth), state kept across buffers.
    private var hb0: Float = 1, hb1: Float = 0, hb2: Float = 0, ha1: Float = 0, ha2: Float = 0
    private var hx1: Float = 0, hx2: Float = 0, hy1: Float = 0, hy2: Float = 0
    private var loudStreak = 0.0

    // Downsampling to ~16 kHz mono (plenty for snoring, and small files).
    private var inRate = 0.0
    private var outRate = 16000.0
    private var ratio = 1.0
    private var dsPos = 0.0
    private var dsSum: Float = 0
    private var dsCount = 0

    // Room level.
    private var calibration: [Double] = []
    private var calibrationTime = 0.0
    private(set) var floor: Double?
    private var window: [(time: Date, db: Double)] = []
    private var lastFloorCalc = Date.distantPast

    // Detection.
    private var loudTime = 0.0
    private var preroll: [[Float]] = []
    private var prerollCount = 0
    private var rec: Recording?
    private var lastUpdate = Date.distantPast
    private var summary: [Double] = []
    private var summaryStart = Date()

    private struct Recording {
        var start: Date
        var chunks: [[Float]]
        var count: Int
        var lastLoud: Date
        var lastLoudCount: Int
        var peak: Double
    }

    init(sensitivity: Double, silenceSeconds: Double) {
        self.sensitivity = sensitivity
        self.silenceSeconds = silenceSeconds
    }

    var isRecording: Bool { rec != nil }

    /// Feed one buffer of mono samples from the microphone.
    func process(_ input: [Float], sampleRate: Double, at now: Date) {
        guard !input.isEmpty, sampleRate > 0 else { return }
        if sampleRate != inRate { resetDownsampler(sampleRate) }

        let filtered = highPass(input)
        var sq: Double = 0
        for v in filtered { sq += Double(v) * Double(v) }
        let db = 20 * log10(sqrt(sq / Double(filtered.count)) + 1e-9)
        let seconds = Double(input.count) / sampleRate
        let chunk = downsample(filtered)

        trackRoom(now: now, db: db)

        if floor == nil {
            calibration.append(db)
            calibrationTime += seconds
            pushPreroll(chunk)
            if calibrationTime >= calibrationSeconds {
                let sorted = calibration.sorted()
                floor = sorted[sorted.count / 2]
            }
            sendUpdate(now: now, db: db)
            return
        }

        let trigger = (floor ?? db) + sensitivity
        if rec != nil {
            // Mutate in place (no copy of the growing clip on every buffer).
            rec!.chunks.append(chunk)
            rec!.count += chunk.count
            if db > trigger - 3 {
                loudStreak += seconds
                rec!.peak = max(rec!.peak, db)
                if loudStreak >= loudToResetSeconds {
                    rec!.lastLoud = now
                    rec!.lastLoudCount = rec!.count
                }
            } else {
                loudStreak = 0
            }
            if now.timeIntervalSince(rec!.lastLoud) > silenceSeconds {
                finish(trim: true)
            } else if Double(rec!.count) / outRate >= maxClipSeconds {
                finish(trim: false)
            }
        } else {
            pushPreroll(chunk)
            if db > trigger {
                loudTime += seconds
                if loudTime >= triggerSeconds { startClip(now: now, db: db) }
            } else {
                loudTime = 0
            }
        }
        sendUpdate(now: now, db: db)
    }

    /// Save the clip in progress now (on stop, or when iOS interrupts for an alarm or call).
    func flush() {
        if rec != nil { finish(trim: false) }
        preroll = []
        prerollCount = 0
        loudTime = 0
    }

    // MARK: - Internals

    private func resetDownsampler(_ rate: Double) {
        inRate = rate
        outRate = min(targetRate, rate)
        ratio = rate / outRate
        dsPos = 0; dsSum = 0; dsCount = 0
        // High-pass coefficients (RBJ cookbook, Q = 0.7071).
        let w0 = 2 * Double.pi * highPassHz / rate
        let alpha = sin(w0) / (2 * 0.7071067811865476)
        let c = cos(w0), a0 = 1 + alpha
        hb0 = Float((1 + c) / 2 / a0); hb1 = Float(-(1 + c) / a0); hb2 = hb0
        ha1 = Float(-2 * c / a0); ha2 = Float((1 - alpha) / a0)
        hx1 = 0; hx2 = 0; hy1 = 0; hy2 = 0
        // A clip can't mix sample rates; save what we have.
        if rec != nil { finish(trim: false) }
        preroll = []; prerollCount = 0
    }

    private func highPass(_ x: [Float]) -> [Float] {
        var out = [Float](repeating: 0, count: x.count)
        for i in x.indices {
            let v = x[i]
            let y = hb0 * v + hb1 * hx1 + hb2 * hx2 - ha1 * hy1 - ha2 * hy2
            hx2 = hx1; hx1 = v; hy2 = hy1; hy1 = y
            out[i] = y
        }
        return out
    }

    private func downsample(_ x: [Float]) -> [Float] {
        var out: [Float] = []
        out.reserveCapacity(Int(Double(x.count) / ratio) + 2)
        for v in x {
            dsSum += v; dsCount += 1; dsPos += 1
            if dsPos >= ratio {
                out.append(max(-1, min(1, dsSum / Float(dsCount))))
                dsPos -= ratio; dsSum = 0; dsCount = 0
            }
        }
        return out
    }

    private func trackRoom(now: Date, db: Double) {
        window.append((now, db))
        if let cut = window.firstIndex(where: { now.timeIntervalSince($0.time) <= floorWindow }), cut > 0 {
            window.removeFirst(cut)
        }
        if floor != nil, now.timeIntervalSince(lastFloorCalc) >= 1, window.count >= 20 {
            lastFloorCalc = now
            let sorted = window.map(\.db).sorted()
            floor = sorted[min(sorted.count - 1, sorted.count / 10)]
        }
        summary.append(db)
        if now.timeIntervalSince(summaryStart) >= 30 {
            if let floor {
                let sorted = summary.sorted()
                onLevel?(LevelSample(time: now, level: sorted[sorted.count / 2], trigger: floor + sensitivity))
            }
            summary = []
            summaryStart = now
        }
    }

    private func pushPreroll(_ chunk: [Float]) {
        preroll.append(chunk)
        prerollCount += chunk.count
        while let first = preroll.first, prerollCount - first.count > Int(prerollSeconds * outRate) {
            prerollCount -= first.count
            preroll.removeFirst()
        }
    }

    private func startClip(now: Date, db: Double) {
        let start = now.addingTimeInterval(-Double(prerollCount) / outRate)
        rec = Recording(start: start, chunks: preroll, count: prerollCount,
                        lastLoud: now, lastLoudCount: prerollCount, peak: db)
        loudStreak = 0
        preroll = []
        prerollCount = 0
        loudTime = 0
    }

    private func finish(trim: Bool) {
        guard let r = rec else { return }
        rec = nil
        let keep = trim ? min(r.count, r.lastLoudCount + Int(tailSeconds * outRate)) : r.count
        var samples: [Float] = []
        samples.reserveCapacity(keep)
        for chunk in r.chunks {
            if samples.count >= keep { break }
            samples.append(contentsOf: chunk.prefix(keep - samples.count))
        }
        guard samples.count > Int(outRate / 2) else { return }   // ignore fragments under half a second

        // Lift quiet clips so they're easy to hear (at most 8x).
        var peak: Float = 1e-6
        for v in samples { peak = max(peak, abs(v)) }
        let gain = min(8, 0.89 / peak)
        if gain > 1.05 { for i in samples.indices { samples[i] *= gain } }

        let duration = Double(samples.count) / outRate
        onClip?(FinishedClip(start: r.start, end: r.start.addingTimeInterval(duration),
                             peakDb: r.peak, samples: samples, sampleRate: outRate))
    }

    private func sendUpdate(now: Date, db: Double) {
        guard now.timeIntervalSince(lastUpdate) >= 0.1 else { return }
        lastUpdate = now
        let phase: Phase = floor == nil ? .calibrating : (rec != nil ? .recording : .listening)
        onUpdate?(Update(level: db, floor: floor, trigger: floor.map { $0 + sensitivity }, phase: phase,
                         quietFor: rec.map { now.timeIntervalSince($0.lastLoud) }))
    }
}
