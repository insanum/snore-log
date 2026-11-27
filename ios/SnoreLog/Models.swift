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
