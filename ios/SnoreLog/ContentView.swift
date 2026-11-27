import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var recorder: Recorder
    @EnvironmentObject private var purchases: Purchases
    @EnvironmentObject private var player: Player
    @Environment(\.scenePhase) private var scenePhase

    @State private var confirmClear = false
    @State private var olderNightCount = 0

    var body: some View {
        NavigationStack {
            List {
                Section {
                    MonitorCard(onStart: startTapped)
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

                Section {
                    if store.nights.isEmpty {
                        Text("No recordings yet. Tap Start listening at bedtime. Each time a sound is detected, a clip is saved here with its date and time, ready to play in the morning.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.nights) { night in
                            NavigationLink(value: night.key) { NightRow(night: night) }
                        }
                    }
                } header: {
                    Text("Nights")
                } footer: {
                    if !purchases.isUnlocked && !store.nights.isEmpty {
                        Text("The free version keeps the most recent night. Unlock to keep every night.")
                    }
                }

                if !purchases.isUnlocked {
                    Section { UnlockCard() }
                }
            }
            .navigationTitle("Snore Log")
            .navigationDestination(for: Date.self) { key in
                NightDetailView(nightKey: key)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { SettingsView() } label: {
                        Image(systemName: "gearshape").accessibilityLabel("Settings")
                    }
                }
            }
            .alert("Start a new night?", isPresented: $confirmClear) {
                Button("Unlock all nights (\(purchases.priceText))") { Task { await purchases.buy() } }
                Button("Clear and start", role: .destructive) {
                    store.deleteAllNights(except: Store.nightKey(for: Date()))
                    begin()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The free version keeps one night. Starting tonight removes \(olderNightCount) earlier night\(olderNightCount == 1 ? "" : "s") and their recordings.")
            }
            .alert("Snore Log", isPresented: Binding(get: { purchases.message != nil },
                                                     set: { if !$0 { purchases.message = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(purchases.message ?? "")
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { recorder.appBecameActive() }
        }
    }

    private func startTapped() {
        let tonight = Store.nightKey(for: Date())
        let older = store.nights.filter { $0.key != tonight }
        if !purchases.isUnlocked && !older.isEmpty {
            olderNightCount = older.count
            confirmClear = true
        } else {
            begin()
        }
    }

    private func begin() {
        player.stop()
        Task { await recorder.start() }
    }
}

struct NightRow: View {
    let night: Night

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Format.night(night.key)).font(.headline)
            HStack(spacing: 6) {
                Text("\(night.audioClips.count) clip\(night.audioClips.count == 1 ? "" : "s")")
                Text("·")
                Text(Format.duration(night.recordedSeconds))
                if night.micOffSeconds > 0 {
                    Text("·")
                    Text("mic off \(Format.duration(night.micOffSeconds))").foregroundStyle(Theme.rec)
                }
                Text("·")
                Text(Format.size(night.bytes))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct UnlockCard: View {
    @EnvironmentObject private var purchases: Purchases

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Keep every night").font(.headline)
            Text("A one-time purchase. No subscription. Recordings never leave your iPhone.")
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack {
                Button {
                    Task { await purchases.buy() }
                } label: {
                    Text("Unlock for \(purchases.priceText)").fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .disabled(purchases.busy)
                Spacer()
                Button("Restore") { Task { await purchases.restore() } }
                    .disabled(purchases.busy)
            }
        }
        .padding(.vertical, 4)
    }
}
