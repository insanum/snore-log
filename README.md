# Snore Log

**Hear what happens after you fall asleep.** Snore Log listens all night and saves a clip only when it hears something clearly louder than your room. In the morning, every snore is waiting, sorted by night and time, ready to play, share or delete.

- **Website:** [insanum.github.io/snore-log](https://insanum.github.io/snore-log/)
- **Web app:** [insanum.github.io/snore-log/app](https://insanum.github.io/snore-log/app/)
- **iPhone app:** App Store coming soon, or [build it yourself](#build-the-iphone-app-yourself)
- **Privacy:** [insanum.github.io/snore-log/privacy.html](https://insanum.github.io/snore-log/privacy.html)

Free, open source (MIT), no account, no subscription. Recordings stay on your device.

---

## Contents

- [What it does](#what-it-does)
- [Web app or iPhone app?](#web-app-or-iphone-app)
- [Using the web app](#using-the-web-app)
- [Using the iPhone app](#using-the-iphone-app)
- [Build the iPhone app yourself](#build-the-iphone-app-yourself)
- [How it decides what to record](#how-it-decides-what-to-record)
- [Settings and tuning](#settings-and-tuning)
- [Alarms, calls and "Mic off"](#alarms-calls-and-mic-off)
- [Privacy](#privacy)
- [Troubleshooting](#troubleshooting)
- [Repository layout](#repository-layout)
- [Development](#development)
- [Not a medical device](#not-a-medical-device)
- [License](#license)

---

## What it does

- **Listens all night** and measures how loud your room normally is.
- **Records only when it hears something louder**, such as snoring, and includes the 3 seconds before the sound so you hear the whole snore.
- **Stops after a stretch of quiet** you choose, saves the clip with its date and time, and keeps listening.
- **Groups everything by night**, with each clip's length and loudness.
- **Plays, shares and deletes** clips; delete a whole night in one go.
- **Easy to listen through:** drag the scrub bar, jump back or forward 10 seconds, or **hold the forward button to play at 2×** (voices keep their normal pitch). Pausing keeps your place.
- **Shows gaps honestly**: if an alarm, a call or Siri took the microphone, a **Mic off** entry shows which minutes weren't covered.
- **Gets out of the way of your alarm**: it steps aside when iPhone needs the audio and starts listening again when you stop the alarm.

## Web app or iPhone app?

Both use the same listening rules. The iPhone app can do more because iOS lets real apps keep recording with the screen locked.

| | Web app | iPhone app (App Store) | Build it yourself |
|---|---|---|---|
| **Price** | Free | Free; keeps the latest night. **Unlock all nights** is a one-time **$2.99** purchase (no subscription) | Free, everything unlocked |
| **Install** | None: open in Safari, add to Home Screen | App Store *(coming soon)* | Mac with Xcode; a free Apple Account re-signs every 7 days |
| **Screen during the night** | Must stay on with the app open (a **Dim** button blacks it out) | Lock it; keeps recording in the background | Lock it |
| **Your alarm** | Rings; listening resumes after you stop it | Rings; listening resumes after you stop it | Same |
| **Apple Watch alarm taps** | May only ring on the phone: with the screen on, iPhone treats it as in use | As usual, since the phone is locked | As usual |
| **Space per minute of recording** | About 2 MB (WAV) | About 0.25 MB (compressed AAC) | About 0.25 MB |
| **Nightly chart** | Live sound graph only | Whole-night chart of loudness, trigger level and clips | Yes |
| **Work-managed iPhones** | Works, even where Auto-Lock can't be set to Never | Works if your employer allows App Store apps | Developer Mode may be blocked |
| **Updates** | Automatic: an **Update now** bar appears | App Store | Pull and rebuild |
| **Troubleshooting log** | Yes (**Diagnostics → Copy log**) | Not yet | Xcode console |

**Which should I use?**
- *Trying it out:* the web app. Nothing to install.
- *Every night:* the iPhone app: lock the phone, smaller files, normal watch alarms.
- *Like to tinker:* build it yourself, change anything.

## Using the web app

1. On your iPhone, open **[insanum.github.io/snore-log/app](https://insanum.github.io/snore-log/app/)** in **Safari**.
2. Tap **Share → Add to Home Screen** and use the Snore Log icon from then on. (Home Screen apps keep their data; Safari may clear storage for websites you haven't opened in a week.)
3. At bedtime:
   - Phone on charge, about an arm's length from your head.
   - **Low Power Mode off** (it forces a short Auto-Lock).
   - Do Not Disturb or Sleep Focus on.
4. Tap **Start listening**, allow the microphone, then tap **Dim**. **Leave the app open on screen.** iPhone turns off the microphone for web pages that aren't on screen.

The web app keeps the screen awake by itself while listening, so Auto-Lock doesn't need to be set to Never (handy on work phones where that option is hidden). If you do lock the phone or switch apps, it saves what it had, shows a **Mic off** entry, and starts listening again when you come back.

The footer shows the **version** (git commit) that's running. When a newer version is published, an **Update now** bar appears.

## Using the iPhone app

1. Open Snore Log and tap **Start listening**. Allow the microphone the first time.
2. **Lock the phone.** It keeps listening in the background (the microphone indicator shows it's active).
3. In the morning, open the app, tap last night, and look at the **chart** and the **clips**.

The free App Store version keeps the most recent night. Starting a new night asks before removing earlier ones; **Unlock all nights** (one-time) keeps everything. **Restore** in Settings brings back a purchase on a new phone.

## Build the iPhone app yourself

Requirements: a Mac with **Xcode** (current version; the project targets iOS 17 and later) and an iPhone.

1. Install **Xcode** from the Mac App Store. On first launch, let it install the iOS components.
2. **Xcode → Settings → Accounts → +**: add your Apple Account. A free account works ("Personal Team").
3. Get the code:
   ```sh
   git clone https://github.com/insanum/snore-log.git
   open snore-log/ios/SnoreLog.xcodeproj
   ```
   (Or in Xcode: **Source Control → Clone…** and paste the repository URL.)
4. Click the **SnoreLog** project in the sidebar → **SnoreLog** target → **Signing & Capabilities** → choose your **Team**. If Xcode says the bundle identifier is unavailable, change `com.insanum.snorelog` to something of your own, such as `com.yourname.snorelog`.
5. Connect your iPhone and tap **Trust** on it.
6. On the iPhone: **Settings → Privacy & Security → Developer Mode → On** (the phone restarts).
7. Choose your iPhone at the top of Xcode and press **Run (▶)**.
8. If iPhone says *Untrusted Developer*: **Settings → General → VPN & Device Management** → your Apple Account → **Trust**.

Notes:
- With a free Apple Account the app keeps working for **7 days**; press Run again to renew.
- Builds you run from Xcode are **always fully unlocked**. To test the free limit and purchase flow, turn on **Settings → Simulate free version** (Debug builds only); purchases then use the StoreKit test file `ios/Config/SnoreLog.storekit`.
- **Work-managed iPhones** may hide Developer Mode or block trusting your certificate. Use a personal device, or wait for the App Store version.

## How it decides what to record

The web app and iPhone app use the same rules:

1. **Learns the room.** For the first 2.5 seconds it measures the room's sound level.
2. **Keeps tracking the room.** The room level is the quietest 10% of the last 60 seconds, updated all night, *including while recording*. Snoring has quiet gaps between breaths, so the room level holds steady while you snore; a steady new noise (fan, heater) lifts it within about a minute, so a recording can't run until morning.
3. **Triggers on louder sounds.** A clip starts when the sound is **sensitivity** dB above the room (default **+12 dB**) for at least a quarter of a second.
4. **Keeps a lead-in.** Each clip includes the **3 seconds before** the trigger.
5. **Ends after quiet.** The clip ends after the **silence** time you choose (default **2 minutes**) without loud sounds; the quiet tail is trimmed to 4 seconds. Only a sound that stays **above the trigger for 0.4 seconds in a row** restarts this countdown, so clicks, rustles and other short blips don't keep a recording going. While recording, the screen shows the countdown, e.g. **Quiet 0:23 of 1:00**.
6. **Splits long clips** at 20 minutes.
7. **Saves small, audible files.** Audio is downsampled to 16 kHz mono (plenty for snoring), and quiet clips are boosted (up to 8×) so they're easy to hear.

The iPhone app also **filters out deep rumble below about 80 Hz** (air handling, traffic, the building) before measuring. It uses the raw microphone so levels stay consistent all night, and without the filter that rumble could keep recordings from ending. Snoring is well above 80 Hz. The web app gets audio that iPhone has already cleaned up, so it doesn't need this.

## Settings and tuning

| Setting | Default | What it does |
|---|---|---|
| **Sensitivity** | +12 dB | How much louder than the room a sound must be to start recording. |
| **Stop after silence of** | 2 minutes | How long without loud sounds before a clip ends. |

**About the numbers.** Snore Log measures sound relative to the microphone's maximum, so levels are negative (a quiet room is around −60 dB). Your Apple Watch measures absolute loudness (a quiet bedroom is about 30–45 dB). Snore Log only compares sounds with your own room, so the two scales don't need to match. Every +10 dB sounds roughly twice as loud.

**Tuning after a night or two:**
- Clips are mostly rustling, a partner or other noises: raise sensitivity to **+15 to +18**.
- Quiet snoring is missing: lower it to **+8 to +10**.
- Clips are split into many short pieces: lengthen the silence time.
- Recordings run much longer than the silence time: watch the **Quiet** countdown while it records. If it keeps dropping back to 0:00 when the room seems silent, something in the room is louder than the trigger; raise sensitivity a few dB.

The yellow line on the live graph is the trigger level: sounds above it are recorded. Next to the live level, the app shows the trigger level and, while recording, the quiet countdown.

## Alarms, calls and "Mic off"

When iPhone needs the audio for an **alarm**, a **phone call** or **Siri**, Snore Log:

1. saves the clip it was recording,
2. shows **Paused** and doesn't touch the microphone (so your alarm sounds),
3. starts listening again when iPhone hands the audio back (for example when you stop the alarm), or when you tap **Resume listening**. The web app also resumes by itself after 30 minutes if iPhone never signals the end.

Any time the microphone was off appears in the night's list as **Mic off** with exact times. In the web app, locking the screen or switching apps also causes a short **Mic off** entry.

## Privacy

- Recordings are stored **only on your device** (the app's own storage, or the browser's storage for the web app). Nothing is uploaded.
- No account, no ads, no analytics, no third-party code.
- The web app's only network request is checking this site for a newer version of itself.
- The optional purchase is handled entirely by Apple.

Full text: [privacy page](https://insanum.github.io/snore-log/privacy.html).

## Troubleshooting

**Web app**
- *Stays on "Mic off" after coming back:* tap **Resume listening**. If it still doesn't recover, open **Diagnostics → Copy log** and [open an issue](https://github.com/insanum/snore-log/issues) with the log.
- *Asks for the microphone again:* allow it; iPhone sometimes asks again when a web page restarts the microphone.
- *Old version still showing:* tap **Update now**, or close the app from the app switcher and reopen it.
- *Screen turned off overnight:* the screen must stay on for web apps. Turn off Low Power Mode; if your phone still locks, use Guided Access (Settings → Accessibility) or the iPhone app.

**iPhone app**
- *"Microphone access is off":* **Settings → Privacy & Security → Microphone → Snore Log**.
- *No clips after a night:* check the night's chart. If the level line never crosses the dashed trigger line, lower the sensitivity.
- *Clips much longer than expected:* see "Recordings run much longer than the silence time" under [Settings and tuning](#settings-and-tuning).
- *App stopped opening after a week (self-built):* free Apple Account installs expire after 7 days. Connect the phone and press Run in Xcode again; recordings are kept.

## Repository layout

```
web/                    GitHub Pages site
  index.html            home page
  app/index.html        the web app (one self-contained HTML file)
  privacy.html          privacy page (also used for the App Store)
  img/                  screenshots and icons
ios/                    iPhone app (SwiftUI, iOS 17+)
  SnoreLog.xcodeproj    Xcode project (files in SnoreLog/ are picked up automatically)
  SnoreLog/
    Detector.swift      listening rules (same as the web app)
    Recorder.swift      microphone, background recording, alarm/call handling
    ClipWriter.swift    saves clips as .m4a
    Models.swift        nights, clips, storage
    Purchases.swift     one-time $2.99 unlock (StoreKit 2)
    PrivacyInfo.xcprivacy  privacy manifest (no tracking, no data collected)
    *View.swift         screens: monitor, nights, night detail with chart, settings
  Config/
    Info.plist          background audio mode
    SnoreLog.storekit   StoreKit test configuration
  APP_STORE.md          publishing guide: listing text, purchase setup, review notes, checklist
.github/workflows/
  pages.yml             publishes web/ to GitHub Pages, stamping the commit hash
  ios.yml               compiles the iPhone app on macOS for every change under ios/
```

## Development

- **Web app:** plain HTML, CSS and JavaScript in `web/app/index.html`; no build step. Serve `web/` locally (`python3 -m http.server -d web`) and open `http://localhost:8000/app/`. The microphone needs `localhost` or HTTPS.
- **Publishing:** every push to `main` that touches `web/` publishes the site. The workflow writes the commit hash into each page; the web app shows it in its footer and uses it to offer updates.
- **iPhone app:** open `ios/SnoreLog.xcodeproj` in Xcode. Every push touching `ios/` is compiled (Debug and Release) on a GitHub-hosted Mac, see the **iOS build** workflow.
- **Keep the two in step:** changes to the listening rules should be made in both `web/app/index.html` and `ios/SnoreLog/Detector.swift`.

Issues and pull requests are welcome.

## Not a medical device

Snore Log records sound. It does not diagnose snoring, sleep apnea or any other condition. If you're worried about your sleep, talk to a doctor; the recordings can be useful to bring along.

## License

[MIT](LICENSE). Use it, change it, share it.
