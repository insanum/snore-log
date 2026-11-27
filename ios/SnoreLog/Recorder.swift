import AVFoundation
import Combine

enum ListenState: Equatable {
    case idle
    case starting
    case calibrating
    case listening
    case recording
    /// iOS gave the audio to something more important (alarm, call, Siri). Resumes when that ends.
    case paused(String)
    case failed(String)
}

/// Runs the microphone, feeds the detector, saves clips and handles iOS audio interruptions.
/// Keeps working with the screen locked (background audio mode) while listening.
@MainActor
final class Recorder: ObservableObject {
    @Published private(set) var state: ListenState = .idle
    @Published private(set) var level: Double = -100
    @Published private(set) var floor: Double?
    @Published private(set) var trigger: Double?
    /// Last 60 seconds of levels, about 10 per second, for the live graph.
    @Published private(set) var history: [Double] = []
    @Published private(set) var sessionStart: Date?
    @Published private(set) var clipsThisSession = 0
    @Published private(set) var recordedSeconds: TimeInterval = 0

    nonisolated static let sensitivityKey = "sensitivity"
    nonisolated static let silenceKey = "silenceSeconds"
    nonisolated static let defaultSensitivity = 12.0
    nonisolated static let defaultSilence = 120

    var isRunning: Bool {
        switch state {
        case .idle, .failed: return false
        default: return true
        }
    }

    var isPaused: Bool {
        if case .paused = state { return true }
        return false
    }

    private let store: Store
    private var engine = AVAudioEngine()
    private let audioQueue = DispatchQueue(label: "com.insanum.snorelog.audio", qos: .userInitiated)
    private var detector: Detector?
    private var gapStart: Date?
    private var resumeTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []

    init(store: Store) {
        self.store = store
        addObservers()
    }

    // MARK: - Start / stop

    func start() async {
        guard !isRunning else { return }
        state = .starting
        guard await AVAudioApplication.requestRecordPermission() else {
            state = .failed("Microphone access is off. Turn it on in Settings → Privacy & Security → Microphone → Snore Log.")
            return
        }
        let defaults = UserDefaults.standard
        detector = Self.makeDetector(
            sensitivity: defaults.object(forKey: Self.sensitivityKey) as? Double ?? Self.defaultSensitivity,
            silence: Double(defaults.object(forKey: Self.silenceKey) as? Int ?? Self.defaultSilence),
            recordingsDir: store.recordingsDir,
            recorder: self)
        sessionStart = Date()
        clipsThisSession = 0
        recordedSeconds = 0
        history = []
        floor = nil
        trigger = nil
        gapStart = nil
        do {
            try startEngine()
            state = .calibrating
        } catch {
            detector = nil
            state = .failed("Couldn't start the microphone (\(error.localizedDescription)).")
        }
    }

    func stop() {
        guard isRunning else { return }
        resumeTask?.cancel()
        closeGap()
        stopEngine()
        if let det = detector { audioQueue.async { det.flush() } }
        detector = nil
        state = .idle
        level = -100
    }

    /// Try to start listening again after an interruption (also used by the Resume button).
    func resume() {
        guard isRunning, isPaused else { return }
        do {
            try startEngine()
            closeGap()
            state = .listening
        } catch {
            state = .paused("Couldn't restart the microphone yet. Tap Resume to try again.")
        }
    }

    /// Called when the app comes back to the screen.
    func appBecameActive() {
        if isPaused { resume() }
    }

    // MARK: - Engine

    private func startEngine() throws {
        let session = AVAudioSession.sharedInstance()
        // .measurement turns off iOS voice processing and automatic gain, so levels stay comparable all night.
        try session.setCategory(.record, mode: .measurement, options: [])
        try session.setActive(true)

        engine.stop()
        let input = engine.inputNode
        input.removeTap(onBus: 0)
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw NSError(domain: "SnoreLog", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "no microphone input is available"])
        }
        guard let det = detector else { return }
        input.installTap(onBus: 0, bufferSize: 4096, format: format,
                         block: Self.makeTap(detector: det, queue: audioQueue))
        engine.prepare()
        try engine.start()
    }

    private func stopEngine() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Built outside the main actor: the tap runs on an audio thread.
    nonisolated private static func makeTap(detector: Detector, queue: DispatchQueue) -> AVAudioNodeTapBlock {
        return { buffer, _ in
            guard let channel = buffer.floatChannelData?[0] else { return }
            let count = Int(buffer.frameLength)
            let rate = buffer.format.sampleRate
            let samples = Array(UnsafeBufferPointer(start: channel, count: count))
            let now = Date()
            queue.async { detector.process(samples, sampleRate: rate, at: now) }
        }
    }

    /// Built outside the main actor: the detector's callbacks run on the audio queue.
    nonisolated private static func makeDetector(sensitivity: Double, silence: Double,
                                                 recordingsDir: URL, recorder: Recorder) -> Detector {
        let det = Detector(sensitivity: sensitivity, silenceSeconds: silence)
        weak var weakRecorder = recorder
        det.onUpdate = { update in
            let r = weakRecorder
            Task { @MainActor in r?.apply(update) }
        }
        det.onLevel = { sample in
            let r = weakRecorder
            Task { @MainActor in r?.store.addLevel(sample) }
        }
        det.onClip = { finished in
            do {
                let written = try ClipWriter.write(finished.samples, sampleRate: finished.sampleRate,
                                                   start: finished.start, to: recordingsDir)
                let clip = Clip(kind: .audio, start: finished.start, end: finished.end, peakDb: finished.peakDb,
                                fileName: written.fileName, bytes: written.bytes)
                let r = weakRecorder
                Task { @MainActor in r?.saved(clip) }
            } catch {
                print("Snore Log: could not save clip: \(error)")
            }
        }
        return det
    }

    private func apply(_ update: Detector.Update) {
        guard isRunning, !isPaused else { return }
        level = update.level
        floor = update.floor
        trigger = update.trigger
        history.append(update.level)
        if history.count > 600 { history.removeFirst(history.count - 600) }
        switch update.phase {
        case .calibrating: state = .calibrating
        case .listening: state = .listening
        case .recording: state = .recording
        }
    }

    private func saved(_ clip: Clip) {
        store.add(clip)
        clipsThisSession += 1
        recordedSeconds += clip.duration
    }

    private func closeGap() {
        guard let start = gapStart else { return }
        gapStart = nil
        let end = Date()
        if end.timeIntervalSince(start) >= 5 {
            store.add(Clip(kind: .gap, start: start, end: end))
        }
    }

    // MARK: - iOS audio events

    private func interruptionBegan() {
        guard isRunning else { return }
        resumeTask?.cancel()
        if let det = detector { audioQueue.async { det.flush() } }
        engine.stop()
        if gapStart == nil { gapStart = Date() }
        state = .paused("Paused for an alarm, call or Siri. Listening resumes when it ends.")
    }

    private func interruptionEnded() {
        guard isRunning, isPaused else { return }
        // Give the alarm or call a moment to release the audio, then start again.
        resumeTask?.cancel()
        resumeTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            self?.resume()
        }
    }

    private func restartAfterConfigurationChange() {
        guard isRunning, !isPaused else { return }
        do { try startEngine() } catch {
            if gapStart == nil { gapStart = Date() }
            state = .paused("The microphone changed. Tap Resume to continue.")
        }
    }

    private func settingsChanged() {
        guard let det = detector else { return }
        let defaults = UserDefaults.standard
        let sensitivity = defaults.object(forKey: Self.sensitivityKey) as? Double ?? Self.defaultSensitivity
        let silence = Double(defaults.object(forKey: Self.silenceKey) as? Int ?? Self.defaultSilence)
        audioQueue.async {
            det.sensitivity = sensitivity
            det.silenceSeconds = silence
        }
    }

    private func addObservers() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
                                            object: nil, queue: .main) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let began = raw == AVAudioSession.InterruptionType.began.rawValue
            Task { @MainActor in
                if began { self?.interruptionBegan() } else { self?.interruptionEnded() }
            }
        })
        observers.append(center.addObserver(forName: .AVAudioEngineConfigurationChange,
                                            object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.restartAfterConfigurationChange() }
        })
        observers.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification,
                                            object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.engine = AVAudioEngine()
                self.restartAfterConfigurationChange()
            }
        })
        observers.append(center.addObserver(forName: UserDefaults.didChangeNotification,
                                            object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.settingsChanged() }
        })
    }
}
