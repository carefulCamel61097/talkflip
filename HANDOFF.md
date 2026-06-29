# Handoff — cloud STT milestone → iOS release

**As of 2026-06-29, on the Windows machine.** Read alongside `ROADMAP.md`
("Language-specific STT (cloud fallback)") and `CLAUDE.md`.

## What changed and why

We migrated speech-to-text from the native **on-device** recognizers to **cloud
streaming** (Deepgram, via a Cloudflare Worker WebSocket relay), because hands-on
testing showed on-device STT was worse than Google Translate even for English.
Cloud STT is now the **default engine**. Then three follow-up steps, all
committed:

- **Step 7 — resilience + commit cadence** (`a1d08fb`). `ResilientSttEngine`
  wraps cloud + on-device: on a cloud failure (connect refused, mid-session
  drop, mic fail) it transparently restarts the same turn on the on-device
  recognizer and shows a subtle amber "basic speech recognition" dot (only while
  online, so it never collides with the offline dot); reconnects lazily per-turn,
  gated by connectivity + a 30s post-failure cooldown. A bubble now commits on
  the **first** of: Deepgram `speech_final` (~300ms, acoustic), `UtteranceEnd`
  (~1s, word-gap, via `utterance_end_ms=1000`), or a **3s client-side hard
  ceiling** — so it can never hang.
- **Step 8 — privacy (repo side)** (`f733f56`). `docs/privacy.html` (live),
  `docs/index.md`, and the in-app About now disclose that mic audio is streamed
  off-device to Deepgram (via the Cloudflare proxy), with the on-device engine as
  an offline fallback. The old "audio never leaves the device" claim is gone.
  **Store side is still pending** (see below).
- **Step 9 — metering + endpoint guard** (`631b8d4`). The Worker meters uploaded
  audio (32000 B/s → seconds) into KV (`mins:<device>:<month>` +
  `mins:global:<month>`), caps it (**120 min/device/month**, **2000 min/month
  global**), and gates `/stt-stream` with a shared `STT_APP_TOKEN`. Over a cap or
  a bad token → the WS upgrade is refused → the app falls back to on-device
  (degraded, not dead). An anonymous per-install `device` id attributes usage.

## State right now

- **Android build 10** (`1.1.0+10`, commit `922d2b4`) is built and **submitted
  to Play Console review.** AAB: `build/app/outputs/bundle/release/app-release.aab`.
- The **Cloudflare Worker is deployed** (shared backend — iOS uses the same one).
  The `STT_APP_TOKEN` Worker secret is set and matches the committed default in
  `lib/core/config.dart`, so iOS needs no extra config to talk to it.
- ⚠️ **The cloud-STT stack has only ever been tested on Android (an Oppo).** It
  has **never run on iOS** — raw mic capture via the `record` package,
  PCM16/16k/mono over WebSocket, Deepgram. This is the main risk for the iOS
  release.

## What to do on the Mac (iOS)

1. **Test cloud STT on a real iPhone before building a release.** Confirm: the
   live bubble streams, accuracy is good, bubbles commit promptly, and
   side-switching works. Then force the fallback
   (`flutter run --dart-define=STT_APP_TOKEN=nope`) and confirm it drops to
   on-device STT + shows the amber dot. Fix any iOS-specific `record` / audio
   issues first — don't assume Android parity.
2. **Build the iOS release at build number 10** (already in `pubspec.yaml`):
   `flutter build ipa --export-options-plist <plist>` (app-store, manual, profile
   "ConvoGo App Store") → `xcrun altool --upload-app --type ios -f
   build/ios/ipa/ConvoGo.ipa --apiKey <KEYID> --apiIssuer <ISSUER>`. The App Store
   Connect API key (.p8) lives in `~/.appstoreconnect/private_keys/`. Keep it
   **iPhone-only** (`TARGETED_DEVICE_FAMILY=1`). Build 10 supersedes the earlier
   iOS build 9. `Info.plist` needs **no changes** — the mic + speech-recognition
   usage strings are still accurate, and the speech-recognition permission is
   still used by the on-device fallback.
3. **Update App Store Connect → App Privacy** to match the new cloud-audio
   reality (it was "Data Not Collected"): disclose **Audio Data** + text (**User
   Content**), used for **App Functionality**, **not linked** to identity, **no
   tracking**. Whether you can keep "Data Not Collected" hinges on **Deepgram's
   no-retention** setting — see the step-8 notes in `ROADMAP.md`. Mirror whatever
   you entered in the Play **Data Safety** form.
4. **Submit for review.**

## Working style (reminder)

Build/verify hands-on before committing; one commit per milestone; the folder is
"Translator app" but the repo/package is **talkflip**; a sibling **SportsPort**
project sits next door — avoid build/AAB/IPA mix-ups.
