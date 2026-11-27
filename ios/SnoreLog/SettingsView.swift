import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var purchases: Purchases

    @AppStorage(Recorder.sensitivityKey) private var sensitivity = Recorder.defaultSensitivity
    @AppStorage(Recorder.silenceKey) private var silence = Recorder.defaultSilence
    #if DEBUG
    @AppStorage(Purchases.simulateFreeKey) private var simulateFree = false
    #endif

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Sensitivity")
                        Spacer()
                        Text("+\(Int(sensitivity)) dB").monospacedDigit().foregroundStyle(Theme.moon)
                    }
                    Slider(value: $sensitivity, in: 4...30, step: 1)
                }
                Picker("Stop after silence of", selection: $silence) {
                    Text("1 minute").tag(60)
                    Text("2 minutes").tag(120)
                    Text("3 minutes").tag(180)
                    Text("5 minutes").tag(300)
                }
            } header: {
                Text("Listening")
            } footer: {
                Text("Sensitivity is how much louder than the room a sound must be to start recording. Lower numbers record quieter sounds. Around +12 suits most bedrooms; raise it if a partner, fan or rustling sets it off.")
            }

            Section("Purchase") {
                if purchases.isUnlocked {
                    Label("All nights are kept", systemImage: "checkmark.seal.fill")
                } else {
                    UnlockCard()
                }
                #if DEBUG
                Toggle("Simulate free version", isOn: $simulateFree)
                Text("Debug builds are always unlocked. Turn this on to test the free limit and the purchase flow with the StoreKit test file.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                #endif
            }

            Section("Storage") {
                LabeledContent("Nights", value: "\(store.nights.count)")
                LabeledContent("Recordings", value: Format.size(store.totalBytes))
            }

            Section {
                Link("Source code on GitHub", destination: URL(string: "https://github.com/insanum/snore-log")!)
                Link("Web version", destination: URL(string: "https://insanum.github.io/snore-log/")!)
                Link("Privacy", destination: URL(string: "https://insanum.github.io/snore-log/privacy.html")!)
                LabeledContent("Version", value: appVersion)
            } header: {
                Text("About")
            } footer: {
                Text("Snore Log is open source (MIT). Recordings stay on your iPhone. Snore Log records sound; it doesn't diagnose snoring or sleep apnea.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
