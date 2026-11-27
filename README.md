# Snore Log

Records your snoring while you sleep. It listens all night, saves a clip only when it hears something clearly louder than the room, and stops after a stretch of silence. Each night's clips are listed with their date and time, ready to play back, share or delete.

Recordings stay on your device. No account, no tracking, no subscription.

## Three ways to use it

| | What you need | Cost |
|---|---|---|
| **Web app** | Safari on iPhone: open [insanum.github.io/snore-log](https://insanum.github.io/snore-log/) and tap Share → Add to Home Screen. Keep the app open on screen all night. | Free |
| **iPhone app, App Store** | Coming soon. Free download keeps the most recent night; a one-time purchase keeps every night. | Free / one-time unlock |
| **iPhone app, build it yourself** | A Mac with Xcode. Everything is unlocked. See below. | Free |

The iPhone app can record with the **screen locked**, which the web app can't, and handles alarms and calls the way iPhone apps should.

## Build the iPhone app yourself

1. Install **Xcode** from the Mac App Store (free).
2. Clone this repository and open `ios/SnoreLog.xcodeproj`.
3. In Xcode, select the **SnoreLog** target → **Signing & Capabilities** → choose your **Team** (a free Apple Account works: "Personal Team"). If Xcode says the bundle identifier is taken, change `com.insanum.snorelog` to something of your own, such as `com.yourname.snorelog`.
4. Connect your iPhone, select it at the top of the Xcode window, and press **Run** (▶).
5. The first time, on the iPhone: **Settings → Privacy & Security → Developer Mode** → on (iPhone restarts), and **Settings → General → VPN & Device Management** → trust your developer certificate.

With a free Apple Account the app keeps working for 7 days; run it from Xcode again to renew. Builds you run from Xcode are always fully unlocked.

## How it decides what to record

- Measures the room for a few seconds, then keeps tracking it as the quietest 10% of the last minute.
- Starts a clip when a sound is **sensitivity** dB louder than the room (default +12) for a quarter of a second, including the 3 seconds before it.
- Ends the clip after the chosen **silence** time (default 2 minutes), trimming the quiet tail. Long clips are split at 20 minutes.
- If an alarm, call or Siri takes the audio, it saves the clip in progress, waits, and resumes when that ends. Any time the mic was off is shown as a **Mic off** entry.

## Repository layout

- `web/` — the web app (a single HTML file) and the privacy page, published to GitHub Pages.
- `ios/` — the iPhone app (SwiftUI, iOS 17+).
- `.github/workflows/` — publishes the web app, and compiles the iPhone app on every change.

## Not a medical device

Snore Log records sound. It does not diagnose snoring, sleep apnea or any other condition.

## License

[MIT](LICENSE)
