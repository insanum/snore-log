import SwiftUI
import Charts

struct NightDetailView: View {
    let nightKey: Date

    @EnvironmentObject private var store: Store
    @EnvironmentObject private var recorder: Recorder
    @EnvironmentObject private var player: Player
    @Environment(\.dismiss) private var dismiss

    @State private var confirmDelete = false
    @State private var playWhileListening = false

    var body: some View {
        Group {
            if let night = store.night(nightKey) {
                List {
                    Section {
                        NightChart(night: night)
                            .frame(height: 220)
                            .padding(.vertical, 6)
                    } header: {
                        Text("The night")
                    } footer: {
                        Text("The line is the typical sound level; the dashed line is the level that starts a recording. Bars show when clips were saved and when the mic was off.")
                    }

                    Section("Clips") {
                        ForEach(night.clips.reversed()) { clip in
                            if clip.kind == .gap {
                                GapRow(clip: clip)
                            } else {
                                ClipRow(clip: clip, url: store.url(for: clip)) { url in
                                    if recorder.isRunning { playWhileListening = true } else { player.toggle(clip, url: url) }
                                }
                            }
                        }
                        .onDelete { offsets in
                            let items = Array(night.clips.reversed())
                            for i in offsets {
                                if player.activeID == items[i].id { player.stop() }
                                store.delete(items[i])
                            }
                        }
                    }
                }
                .navigationTitle(Format.night(night.key))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) { confirmDelete = true } label: {
                            Image(systemName: "trash").accessibilityLabel("Delete night")
                        }
                    }
                }
                .confirmationDialog("Delete this night?", isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button("Delete \(night.clips.count) item\(night.clips.count == 1 ? "" : "s")", role: .destructive) {
                        player.stop()
                        store.deleteNight(night.key)
                        dismiss()
                    }
                } message: {
                    Text("This removes all of the night's recordings (\(Format.size(night.bytes))).")
                }
                .alert("Stop listening to play clips", isPresented: $playWhileListening) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Playback uses the speaker, which would stop the recording. Stop listening first.")
                }
            } else {
                ContentUnavailableView("Night deleted", systemImage: "moon.zzz")
            }
        }
    }
}

struct NightChart: View {
    let night: Night

    var body: some View {
        Chart {
            ForEach(night.levels, id: \.time) { s in
                LineMark(x: .value("Time", s.time), y: .value("Level", s.level),
                         series: .value("Series", "Level"))
                    .foregroundStyle(Theme.quiet)
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Time", s.time), y: .value("Level", s.trigger),
                         series: .value("Series", "Trigger"))
                    .foregroundStyle(Theme.moon.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
            ForEach(night.clips) { clip in
                RectangleMark(xStart: .value("Start", clip.start), xEnd: .value("End", max(clip.end, clip.start.addingTimeInterval(60))),
                              yStart: .value("Bottom", -95.0), yEnd: .value("Top", -88.0))
                    .foregroundStyle(clip.kind == .gap ? Color.gray.opacity(0.6) : Theme.rec)
            }
        }
        .chartYScale(domain: -95.0 ... -10.0)
        .chartYAxis {
            AxisMarks(position: .leading, values: [-80.0, -60.0, -40.0, -20.0]) { value in
                AxisGridLine()
                AxisValueLabel { if let v = value.as(Double.self) { Text("\(Int(v))") } }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .overlay {
            if night.levels.isEmpty && night.clips.isEmpty {
                Text("No data yet").foregroundStyle(.secondary)
            }
        }
    }
}

private struct ClipRow: View {
    let clip: Clip
    let url: URL?
    let onPlay: (URL) -> Void

    @EnvironmentObject private var player: Player

    var body: some View {
        let active = player.activeID == clip.id
        let playing = active && player.isPlaying
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    if let url { onPlay(url) }
                } label: {
                    Image(systemName: playing ? "pause.fill" : "play.fill")
                        .frame(width: 40, height: 40)
                        .background(active ? Theme.moon : Color.white.opacity(0.08), in: Circle())
                        .foregroundStyle(active ? Color.black : Theme.moon)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(playing ? "Pause" : "Play recording from \(Format.time(clip.start))")

                VStack(alignment: .leading, spacing: 4) {
                    Text(Format.timeWithSeconds(clip.start)).font(.body.monospacedDigit().weight(.semibold))
                    Text("\(Format.duration(clip.duration)) · peak \(Format.db(clip.peakDb)) · \(Format.size(clip.bytes))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let url {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up").accessibilityLabel("Share or save")
                    }
                    .buttonStyle(.borderless)
                }
            }
            if active {
                PlaybackControls()
            }
        }
        .padding(.vertical, 2)
    }
}

/// Scrub bar, 10-second skips, and hold-the-forward-button for 2x speed.
private struct PlaybackControls: View {
    @EnvironmentObject private var player: Player
    @State private var scrubbing = false
    @State private var scrubTime: TimeInterval = 0

    var body: some View {
        VStack(spacing: 6) {
            Slider(value: Binding(get: { scrubbing ? scrubTime : player.currentTime },
                                  set: { scrubTime = $0 }),
                   in: 0...max(player.duration, 0.1),
                   onEditingChanged: { editing in
                       if editing {
                           scrubTime = player.currentTime
                           scrubbing = true
                       } else {
                           player.seek(to: scrubTime)
                           scrubbing = false
                       }
                   })
            .accessibilityLabel("Position")
            HStack {
                Text(Format.duration(scrubbing ? scrubTime : player.currentTime))
                Spacer()
                Button {
                    player.skip(by: -10)
                } label: {
                    Image(systemName: "gobackward.10")
                        .font(.title3)
                        .foregroundStyle(Theme.moon)
                        .frame(width: 44, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Back 10 seconds")
                HoldForFastButton()
                    .padding(.leading, 28)
                Spacer()
                Text("-" + Format.duration(max(0, player.duration - (scrubbing ? scrubTime : player.currentTime))))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(.leading, 52)
        // Keep List row taps from triggering on the controls.
        .buttonStyle(.borderless)
    }
}

/// Tap: forward 10 seconds. Press and hold: play at 2x until released.
private struct HoldForFastButton: View {
    @EnvironmentObject private var player: Player
    @State private var pressStart: Date?
    @State private var holdTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "goforward.10")
                .font(.title3)
                .foregroundStyle(Theme.moon)
                .frame(width: 44, height: 36)
                .contentShape(Rectangle())
            if player.isFast {
                Text("2×")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 4)
                    .background(Theme.moon, in: Capsule())
                    .foregroundStyle(.black)
                    .offset(x: 10, y: -8)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard pressStart == nil else { return }
                    pressStart = Date()
                    holdTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 350_000_000)
                        guard !Task.isCancelled, pressStart != nil else { return }
                        player.setFast(true)
                    }
                }
                .onEnded { _ in
                    holdTask?.cancel()
                    holdTask = nil
                    if player.isFast {
                        player.setFast(false)
                    } else {
                        player.skip(by: 10)
                    }
                    pressStart = nil
                }
        )
        .accessibilityElement()
        .accessibilityLabel("Forward 10 seconds. Hold for double speed.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { player.skip(by: 10) }
    }
}

private struct GapRow: View {
    let clip: Clip

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mic.slash")
                .frame(width: 40, height: 40)
                .foregroundStyle(Theme.rec)
            VStack(alignment: .leading, spacing: 4) {
                Text("Mic off \(Format.timeWithSeconds(clip.start)) – \(Format.timeWithSeconds(clip.end))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.rec)
                Text("\(Format.duration(clip.duration)) not recorded")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}
