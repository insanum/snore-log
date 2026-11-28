import Foundation
import Combine

/// One entry in a night: either a saved recording or a stretch when the mic was off.
struct Clip: Codable, Identifiable, Hashable {
    enum Kind: String, Codable { case audio, gap }

    var id = UUID()
    var kind: Kind
    var start: Date
    var end: Date
    /// Loudest level heard in the clip, in dB relative to the mic's maximum (negative numbers).
    var peakDb: Double?
    /// File name inside the recordings folder (audio clips only).
    var fileName: String?
    var bytes: Int64 = 0

    var duration: TimeInterval { end.timeIntervalSince(start) }
}

/// A sound-level reading taken every 30 seconds while listening, used for the night's chart.
struct LevelSample: Codable, Hashable {
    var time: Date
    /// Typical level over the last 30 seconds.
    var level: Double
    /// Level a sound had to reach to start a recording at that time.
    var trigger: Double
}

/// Everything recorded during one night. A night runs from noon to noon, so a session
/// that starts at 11 pm and ends at 7 am belongs to one night.
struct Night: Codable, Identifiable {
    var key: Date
    var clips: [Clip] = []
    var levels: [LevelSample] = []

    var id: Date { key }
    var audioClips: [Clip] { clips.filter { $0.kind == .audio } }
    var gaps: [Clip] { clips.filter { $0.kind == .gap } }
    var recordedSeconds: TimeInterval { audioClips.reduce(0) { $0 + $1.duration } }
    var micOffSeconds: TimeInterval { gaps.reduce(0) { $0 + $1.duration } }
    var bytes: Int64 { audioClips.reduce(0) { $0 + $1.bytes } }
}

/// Keeps the list of nights and clips, and the recording files, in the app's own storage.
@MainActor
final class Store: ObservableObject {
    @Published private(set) var nights: [Night] = []

    let recordingsDir: URL
    private let indexURL: URL

    init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SnoreLog", isDirectory: true)
        recordingsDir = base.appendingPathComponent("Recordings", isDirectory: true)
        indexURL = base.appendingPathComponent("index.json")
        try? fm.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        load()
    }

    /// Nights run noon to noon.
    nonisolated static func nightKey(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date.addingTimeInterval(-12 * 3600))
    }

    func night(_ key: Date) -> Night? { nights.first { $0.key == key } }

    func url(for clip: Clip) -> URL? {
        clip.fileName.map { recordingsDir.appendingPathComponent($0) }
    }

    var totalBytes: Int64 { nights.reduce(0) { $0 + $1.bytes } }

    func add(_ clip: Clip) {
        let key = Self.nightKey(for: clip.start)
        mutateNight(key) { night in
            night.clips.append(clip)
            night.clips.sort { $0.start < $1.start }
        }
        save()
    }

    func addLevel(_ sample: LevelSample) {
        mutateNight(Self.nightKey(for: sample.time)) { $0.levels.append(sample) }
        save()
    }

    func delete(_ clip: Clip) {
        if let url = url(for: clip) { try? FileManager.default.removeItem(at: url) }
        for i in nights.indices { nights[i].clips.removeAll { $0.id == clip.id } }
        nights.removeAll { $0.clips.isEmpty && $0.levels.isEmpty }
        save()
    }

    func deleteNight(_ key: Date) {
        guard let night = night(key) else { return }
        for clip in night.clips { if let url = url(for: clip) { try? FileManager.default.removeItem(at: url) } }
        nights.removeAll { $0.key == key }
        save()
    }

    /// Free version: keep only the given night.
    func deleteAllNights(except key: Date) {
        for night in nights where night.key != key { deleteNight(night.key) }
    }

    #if DEBUG
    /// Debug builds only: adds a realistic sample night (chart, playable snore-like clips, one Mic off gap),
    /// for App Store screenshots and for trying the app without waiting for a real night.
    func addSampleNight() {
        let yesterday = Date().addingTimeInterval(-86400)
        guard let bedtime = Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: yesterday) else { return }
        var night = Night(key: Self.nightKey(for: bedtime))
        let snoring: [(from: Double, to: Double)] = [(1.6, 2.3), (3.9, 4.4), (5.6, 6.6)]   // hours after 23:00
        var t = 0.0
        while t <= 8 * 3600 {
            let hours = t / 3600
            let room = -62 + 1.5 * sin(t / 1700)
            let isSnoring = snoring.contains { hours >= $0.from && hours <= $0.to }
            let level = room + Double.random(in: -1...1) + (isSnoring ? Double.random(in: 9...16) : 0)
            night.levels.append(LevelSample(time: bedtime.addingTimeInterval(t), level: level, trigger: room + 12))
            t += 30
        }
        let clips: [(hours: Double, seconds: Double, peak: Double)] = [
            (1.62, 48, -31), (1.75, 130, -24), (1.98, 36, -35), (2.2, 95, -27), (3.95, 65, -28),
            (4.25, 40, -33), (5.65, 211, -22), (6.1, 150, -25), (6.45, 70, -29)]
        for c in clips {
            let start = bedtime.addingTimeInterval(c.hours * 3600)
            if let written = try? ClipWriter.write(Self.sampleSnore(seconds: c.seconds), sampleRate: 16000,
                                                   start: start, to: recordingsDir) {
                night.clips.append(Clip(kind: .audio, start: start, end: start.addingTimeInterval(c.seconds),
                                        peakDb: c.peak, fileName: written.fileName, bytes: written.bytes))
            }
        }
        let gap = bedtime.addingTimeInterval(3.2 * 3600)
        night.clips.append(Clip(kind: .gap, start: gap, end: gap.addingTimeInterval(445)))
        night.clips.sort { $0.start < $1.start }
        if let old = self.night(night.key) {
            for clip in old.clips { if let url = url(for: clip) { try? FileManager.default.removeItem(at: url) } }
        }
        nights.removeAll { $0.key == night.key }
        nights.append(night)
        nights.sort { $0.key > $1.key }
        save()
    }

    /// A rough snore: a low buzz with breathy noise, about one every 4 seconds.
    private static func sampleSnore(seconds: Double) -> [Float] {
        let rate = 16000.0
        var out = [Float](repeating: 0, count: Int(seconds * rate))
        var noise: Float = 0
        for i in out.indices {
            let t = Double(i) / rate
            let phase = t.truncatingRemainder(dividingBy: 4.0)
            let envelope = phase < 1.3 ? sin(Double.pi * phase / 1.3) : 0
            noise = 0.97 * noise + 0.03 * Float.random(in: -1...1)
            let buzz = sin(2 * Double.pi * (92 * t + 0.4 * sin(2 * Double.pi * 3 * t)))
            out[i] = Float(envelope) * (0.35 * Float(buzz) + 2.2 * noise) + 0.004 * Float.random(in: -1...1)
        }
        return out
    }
    #endif

    // MARK: - Persistence

    private func mutateNight(_ key: Date, _ change: (inout Night) -> Void) {
        if let i = nights.firstIndex(where: { $0.key == key }) {
            change(&nights[i])
        } else {
            var night = Night(key: key)
            change(&night)
            nights.append(night)
            nights.sort { $0.key > $1.key }
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexURL) else { return }
        do {
            nights = try JSONDecoder().decode([Night].self, from: data).sorted { $0.key > $1.key }
        } catch {
            // Keep the unreadable index aside instead of overwriting it.
            try? FileManager.default.moveItem(at: indexURL, to: indexURL.appendingPathExtension("bad"))
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(nights)
            try data.write(to: indexURL, options: .atomic)
        } catch {
            print("Snore Log: could not save index: \(error)")
        }
    }
}
