# Snore Log on the App Store

Everything needed to publish the iPhone app: the account steps, the text to paste into App Store Connect, and a checklist. Character limits are App Store Connect's.

## 1. Accounts and agreements (one time)

- [ ] Enroll in the **Apple Developer Program** as an individual ($99/year): [developer.apple.com/programs/enroll](https://developer.apple.com/programs/enroll/). The Apple Developer app on iPhone is the quickest way. Your legal name is shown as the seller.
- [ ] **App Store Connect → Business:** accept the **Paid Apps** agreement, add bank details and tax forms (US: W-9). In-app purchases don't work until the Paid Apps agreement is active.
- [ ] Apply for the **App Store Small Business Program** (15% commission instead of 30%): [developer.apple.com/app-store/small-business-program](https://developer.apple.com/app-store/small-business-program/).

## 2. Create the app

**App Store Connect → Apps → + → New App**

| Field | Value |
|---|---|
| Platform | iOS |
| Name | `Snore Log` (if taken: `Snore Log: Sleep Recorder`) |
| Primary language | English (U.S.) |
| Bundle ID | `com.insanum.snorelog` (register it first if it isn't listed: Certificates, Identifiers & Profiles → Identifiers → +) |
| SKU | `snorelog` |
| User access | Full access |

## 3. The unlock purchase

**App → Monetization → In-App Purchases → +**

| Field | Value |
|---|---|
| Type | **Non-Consumable** |
| Reference name | `Unlock all nights` |
| Product ID | `com.insanum.snorelog.unlock` (must match `Purchases.swift` exactly) |
| Price | **$2.99** (USD), other countries at Apple's matching price |
| Family Sharing | On |
| Display name (30) | `Unlock all nights` |
| Description (45) | `Keep every night's recordings, not just one.` |
| Review screenshot | Settings → Purchase section of the free version (see "Screenshots" below) |
| Review notes | `Non-consumable. Without it the app keeps only the most recent night. Buy and Restore are in Settings → Purchase, and the main screen.` |

Submit the purchase **together with the first app version** (it's attached on the version page under "In-App Purchases and Subscriptions").

## 4. Listing text

**Subtitle (30)**
```
Record snoring, not silence
```

**Promotional text (170)**, can be changed any time without review:
```
Snore Log listens all night and keeps only the snores. Lock your phone, sleep, and play them back in the morning. No account, no subscription.
```

**Description (4000)**
```
Hear what happens after you fall asleep.

Snore Log listens all night and saves a clip only when it hears something clearly louder than your room. In the morning, every snore is waiting, sorted by night and time. Eight hours of silence never fill up your phone.

HOW IT WORKS
• Learns your room: it measures how loud your bedroom normally is, and keeps tracking it all night, so a fan switching on doesn't fool it.
• Records the snores: a clip starts when a sound is clearly louder than the room, and includes the 3 seconds before it so you hear the whole snore.
• Stops after quiet: after the silence time you choose, the clip is saved and listening carries on. Clicks and rustles don't keep a recording going.
• Lock your phone: Snore Log keeps listening in the background, so the screen can stay off all night.

YOUR MORNING
• See the whole night on one chart: sound level, the trigger level, and when clips were saved.
• Play any clip, drag through it, jump 10 seconds back or forward, or hold to play at double speed.
• Share a clip with your partner or save it to Files to play for a doctor.
• Delete one clip or a whole night.

PLAYS NICE WITH YOUR ALARM
When an alarm, call or Siri needs the audio, Snore Log saves what it has and steps aside. Your alarm rings as usual, and listening resumes afterwards. Any minutes the microphone was off are clearly marked.

PRIVATE BY DESIGN
• Recordings never leave your iPhone unless you share them.
• No account, no ads, no tracking, no analytics.
• Open source: every line of code is public on GitHub.

FREE TO TRY, NO SUBSCRIPTION
Everything works in the free version, which keeps your most recent night. A single one-time purchase keeps every night. No subscription, ever.

Tip: put your phone on charge about an arm's length from your head. Adjust the sensitivity in Settings if it records too much or too little.

Snore Log records sound. It is not a medical device and does not diagnose snoring, sleep apnea or any other condition.
```

**Keywords (100)**, comma-separated, no spaces after commas:
```
snore,snoring,sleep,recorder,sleep talk,night,noise,partner,bedtime,audio,record,tracker,loud
```

**What's New (first version)**
```
First release.
```

| Field | Value |
|---|---|
| Support URL | `https://github.com/insanum/snore-log/issues` |
| Marketing URL | `https://insanum.github.io/snore-log/` |
| Privacy Policy URL | `https://insanum.github.io/snore-log/privacy.html` |
| Copyright | `2026 <your name>` |
| Primary category | Health & Fitness |
| Secondary category | Lifestyle |
| Price (app) | Free |
| Availability | All countries (or choose) |

## 5. App Privacy and ratings

- **App Privacy → Data collection:** "No, we do not collect data from this app." (Result: *Data Not Collected*.) The app's `PrivacyInfo.xcprivacy` says the same.
- **Age rating questionnaire:** answer *None / No* to everything → **4+**.
- **Export compliance:** already answered in the build (`ITSAppUsesNonExemptEncryption = NO`), so it won't be asked.
- **Content rights:** no third-party content.

## 6. Screenshots

Required: **6.9-inch iPhone** screenshots, portrait (1320 × 2868 or 1290 × 2796). 3–5 is plenty; up to 10 allowed.

How to make them:
1. In Xcode, choose the **iPhone 17 Pro Max** simulator (any 6.9-inch model) and press Run.
2. In the app: **Settings → Add sample night (for screenshots)** (Debug builds only). It creates a realistic night with a chart, playable clips and a Mic off gap.
3. In the Simulator, press **⌘S** to save a screenshot at full resolution (to the Desktop).
4. For the purchase screenshot, turn on **Settings → Simulate free version** first.

Suggested set, in order:
1. **The night's chart and clips** (open the sample night). Caption idea: *Every snore, sorted by night*
2. **A clip playing** with the scrub bar and skip buttons. *Skim a long night in seconds*
3. **Main screen while listening**, with the live graph. *Lock your phone and sleep*
4. **Settings**, sensitivity and silence. *Tune it to your bedroom*
5. **Privacy** (About section). *No account. Nothing leaves your phone*

Captions are optional; plain screenshots are accepted.

## 7. Build and upload

1. Make sure the **bundle ID** in Xcode is `com.insanum.snorelog` and the **Team** is your paid developer team (not the Personal Team).
2. Bump the **build number** (target → General → Build) for every upload; keep **Version** at 1.0 for the first release.
3. At the top of Xcode, choose **Any iOS Device (arm64)**, then **Product → Archive**.
4. In the Organizer: **Distribute App → App Store Connect → Distribute**. Processing takes 5–30 minutes.
5. **TestFlight:** add yourself as an internal tester and install with the TestFlight app. Test the purchase with a **Sandbox** account (App Store Connect → Users and Access → Sandbox → Test Accounts; on the iPhone: Settings → Developer → Sandbox Apple Account). Sandbox purchases are free.

## 8. Submit for review

On the version page: choose the build, attach the **Unlock all nights** purchase, fill in the listing, and add these notes.

**App Review notes**
```
Snore Log records snoring overnight. It listens with the microphone and saves short clips only when a sound is louder than the room.

Background audio: the app declares the "audio" background mode because it records continuously all night while the phone is locked. Recording only happens after the user taps "Start listening", and the system microphone indicator is shown the whole time.

To test: tap "Start listening", allow the microphone, then speak or clap near the phone. A clip starts; after 2 minutes of quiet (or 1 minute if set in Settings) it is saved and appears under tonight's night. Tap the night to see the chart and play clips.

In-app purchase: "Unlock all nights" (non-consumable). The free version keeps only the most recent night and asks before removing older nights. Buy and Restore are in Settings → Purchase.

No account or login. No data is collected or sent anywhere. The app is not a medical device and makes no medical claims.
```

- **Sign-in required:** No.
- **Release:** "Manually release this version" lets you choose the moment after approval.

Review usually takes 1–2 days.

### If App Review pushes back
- **Background audio (Guideline 2.5.4):** point them to the notes above; the app really records continuously in the background.
- **Health claims (1.4.1):** keep "not a medical device" wording; don't mention apnea detection.
- **Purchase (3.1.1):** Restore is in Settings; the free limit is explained before anything is removed.

## 9. After approval

- [ ] Release the version.
- [ ] Update the website and README: replace "coming soon" with the App Store link and the official "Download on the App Store" badge ([Apple marketing resources](https://developer.apple.com/app-store/marketing/guidelines/)).
- [ ] Later releases: bump Version (1.1, …) and Build, archive, upload, add "What's New", submit.
