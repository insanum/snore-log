import AVFoundation
import Combine

/// Plays one clip at a time, with pause/resume, seeking, 10-second skips and a hold-for-2× fast mode.
@MainActor
final class Player: NSObject, ObservableObject, AVAudioPlayerDelegate {
    /// The clip loaded in the player (playing or paused).
    @Published private(set) var activeID: UUID?
    @Published private(set) var isPlaying = false
    @Published private(set) var isFast = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0

    var progress: Double { duration > 0 ? currentTime / duration : 0 }

    private var player: AVAudioPlayer?
    private var timer: Timer?

    /// Tap on a clip's play button: start it, or pause/resume if it's already loaded.
    func toggle(_ clip: Clip, url: URL) {
        if activeID == clip.id, let p = player {
            if p.isPlaying { p.pause(); isPlaying = false } else { p.play(); isPlaying = true }
            return
        }
        stop()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio)
            try session.setActive(true)
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            p.enableRate = true
            p.prepareToPlay()
            p.play()
            player = p
            activeID = clip.id
            isPlaying = true
            duration = p.duration
            currentTime = 0
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
        } catch {
            print("Snore Log: could not play clip: \(error)")
        }
    }

    func seek(to time: TimeInterval) {
        guard let p = player else { return }
        p.currentTime = max(0, min(time, p.duration))
        currentTime = p.currentTime
    }

    func skip(by seconds: TimeInterval) {
        guard let p = player else { return }
        seek(to: p.currentTime + seconds)
    }

    /// Double speed while the finger is held down.
    func setFast(_ fast: Bool) {
        guard let p = player else { return }
        p.rate = fast ? 2.0 : 1.0
        isFast = fast
        if fast && !p.isPlaying { p.play(); isPlaying = true }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        player?.stop()
        player = nil
        activeID = nil
        isPlaying = false
        isFast = false
        currentTime = 0
        duration = 0
    }

    private func tick() {
        guard let p = player else { return }
        currentTime = p.currentTime
        if isPlaying != p.isPlaying { isPlaying = p.isPlaying }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.stop() }
    }
}
