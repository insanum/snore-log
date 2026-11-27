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
                                if player.playingID == items[i].id { player.stop() }
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
        let playing = player.playingID == clip.id
        HStack(spacing: 12) {
            Button {
                if let url { onPlay(url) }
            } label: {
                Image(systemName: playing ? "pause.fill" : "play.fill")
                    .frame(width: 40, height: 40)
                    .background(playing ? Theme.moon : Color.white.opacity(0.08), in: Circle())
                    .foregroundStyle(playing ? Color.black : Theme.moon)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(playing ? "Pause" : "Play recording from \(Format.time(clip.start))")

            VStack(alignment: .leading, spacing: 4) {
                Text(Format.timeWithSeconds(clip.start)).font(.body.monospacedDigit().weight(.semibold))
                Text("\(Format.duration(clip.duration)) · peak \(Format.db(clip.peakDb)) · \(Format.size(clip.bytes))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if playing {
                    ProgressView(value: player.progress).tint(Theme.moon)
                }
            }
            Spacer()
            if let url {
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.up").accessibilityLabel("Share or save")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 2)
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
