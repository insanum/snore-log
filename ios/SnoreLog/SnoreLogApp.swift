import SwiftUI

@main
struct SnoreLogApp: App {
    @StateObject private var store: Store
    @StateObject private var recorder: Recorder
    @StateObject private var purchases = Purchases()
    @StateObject private var player = Player()

    init() {
        UserDefaults.standard.register(defaults: [
            Recorder.sensitivityKey: Recorder.defaultSensitivity,
            Recorder.silenceKey: Recorder.defaultSilence,
        ])
        let store = Store()
        _store = StateObject(wrappedValue: store)
        _recorder = StateObject(wrappedValue: Recorder(store: store))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(recorder)
                .environmentObject(purchases)
                .environmentObject(player)
                .tint(Theme.moon)
                .preferredColorScheme(.dark)
        }
    }
}

enum Theme {
    static let moon = Color(red: 0.949, green: 0.769, blue: 0.427)
    static let rec = Color(red: 1.0, green: 0.478, blue: 0.420)
    static let quiet = Color(red: 0.47, green: 0.53, blue: 0.75)
}
