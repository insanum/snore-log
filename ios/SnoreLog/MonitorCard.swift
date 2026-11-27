import SwiftUI

/// The live panel: status, sound graph with the trigger line, counters and the Start/Stop button.
struct MonitorCard: View {
    @EnvironmentObject private var recorder: Recorder
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                StatusPill(state: recorder.state)
                Spacer()
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(elapsed(at: context.date))
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            LevelGraph(history: recorder.history, trigger: recorder.trigger)
                .frame(height: 84)
                .accessibilityLabel("Sound level over the last minute")

            if recorder.isRunning, !recorder.isPaused {
                HStack {
                    Text("Level \(Format.db(recorder.level)) · trigger \(Format.db(recorder.trigger))")
                    Spacer()
                    if recorder.state == .recording, let quiet = recorder.quietFor {
                        Text("Quiet \(Format.duration(quiet)) of \(Format.duration(recorder.silenceTarget))")
                            .foregroundStyle(Theme.moon)
                    }
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }

            HStack {
                Stat(value: "\(recorder.clipsThisSession)", label: "Clips")
                Stat(value: Format.duration(recorder.recordedSeconds), label: "Recorded")
                Stat(value: Format.db(recorder.floor), label: "Room")
            }

            if recorder.isRunning {
                HStack(spacing: 10) {
                    if recorder.isPaused {
                        Button {
                            recorder.resume()
                        } label: {
                            Text("Resume listening").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Button(role: .destructive) {
                        recorder.stop()
                    } label: {
                        Text("Stop").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.large)
            } else {
                Button(action: onStart) {
                    Text("Start listening").fontWeight(.semibold).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Text(note)
                .font(.footnote)
                .foregroundStyle(noteIsWarning ? Theme.rec : .secondary)
        }
    }

    private var note: String {
        switch recorder.state {
        case .idle: return "Tap Start before you sleep. Put the phone on charge near the bed. You can lock the screen; Snore Log keeps listening."
        case .starting: return "Starting the microphone…"
        case .calibrating: return "Measuring the room for a few seconds. Stay quiet."
        case .listening: return "Listening. A clip is saved whenever a sound is clearly louder than the room. You can lock the screen."
        case .recording: return "Recording. It stops after the silence time you chose."
        case .paused(let why): return why
        case .failed(let why): return why
        }
    }

    private var noteIsWarning: Bool {
        switch recorder.state {
        case .paused, .failed: return true
        default: return false
        }
    }

    private func elapsed(at date: Date) -> String {
        guard recorder.isRunning, let start = recorder.sessionStart else { return "0:00:00" }
        let s = Int(date.timeIntervalSince(start))
        return String(format: "%d:%02d:%02d", s / 3600, s % 3600 / 60, s % 60)
    }
}

private struct StatusPill: View {
    let state: ListenState

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.15), in: Capsule())
        .foregroundStyle(color)
    }

    private var label: String {
        switch state {
        case .idle, .failed: return "Not listening"
        case .starting: return "Starting"
        case .calibrating: return "Calibrating"
        case .listening: return "Listening"
        case .recording: return "Recording"
        case .paused: return "Paused"
        }
    }

    private var color: Color {
        switch state {
        case .recording, .paused: return Theme.rec
        case .listening, .calibrating, .starting: return Theme.moon
        default: return .secondary
        }
    }
}

private struct Stat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(.title3, design: .monospaced).weight(.semibold))
            Text(label.uppercased()).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Bars for the last minute of levels; red above the trigger line, which is drawn in the accent colour.
struct LevelGraph: View {
    let history: [Double]
    let trigger: Double?

    var body: some View {
        Canvas { context, size in
            let lo = -90.0, hi = -10.0
            func y(_ db: Double) -> CGFloat {
                size.height - CGFloat(max(0, min(1, (db - lo) / (hi - lo)))) * size.height
            }
            let slots = 600
            let barWidth = size.width / CGFloat(slots)
            for (i, db) in history.enumerated() {
                let x = CGFloat(slots - history.count + i) * barWidth
                let rect = CGRect(x: x, y: y(db), width: max(1, barWidth), height: size.height - y(db))
                let loud = trigger.map { db > $0 } ?? false
                context.fill(Path(rect), with: .color(loud ? Theme.rec : Theme.quiet.opacity(0.7)))
            }
            if let trigger {
                context.fill(Path(CGRect(x: 0, y: y(trigger), width: size.width, height: 1)), with: .color(Theme.moon))
            }
        }
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
    }
}
