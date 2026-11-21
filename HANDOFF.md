# Handoff — release 1.2.0 (text mode) → Mac session for iOS

**Written 2026-11-21 on the Windows machine.** Read alongside `CLAUDE.md` (product rules, now including text mode) and `ROADMAP.md` → "M11 — Release 1.2.0" (the full to-do list, store chores included).

## Where things stand

- **Live:** iOS 1.1.1 (build 11) on the App Store; Android 1.1.0 (build 10) on Google Play. Both have cloud speech-to-text (Deepgram via the Cloudflare Worker).
- **Code for 1.2.0 is finished** and tested hands-on on Android (Oppo CPH2483). `pubspec.yaml` is already at **1.2.0+12**; don't bump it again for this release.
- **No backend changes** in 1.2.0. Text mode reuses the Worker's existing translate endpoint, so nothing needs deploying.

## What's new in 1.2.0

- **Text mode** (keyboard icon, top left), for chatting in another app. Their side: a **Paste** button reads the clipboard and translates. Your side: a text field; on send the translation is **auto-copied** to the clipboard. Tap the original or the translation inside a bubble to copy just that part. Code: `lib/features/text_mode/`.
- **You on the right in both modes** (WhatsApp convention): your language in green on the right, theirs in white on the left, THEM / YOU labels under the chips. The prefs key `language_pair_left` still holds *your* language; only the position changed, so there's no migration.
- **Conversations are kept on the phone**, one per mode (`lib/core/conversation_store.dart`), until the **Clear** pill (top right, with Undo) is tapped.
- **Long-press a bubble:** text mode offers copy + delete; voice mode offers delete only. Delete has Undo.
- **Read-back check** (text mode, Settings switch, on by default): shows what your translation says back in your language, only when it differs from what you typed.
- **Faster, race-free side switching.** The UI switches instantly, and the cloud engine starts the mic before connecting and buffers the audio. A session-generation guard in `CloudSttEngine` and serialized mic start/stop in `MicAudioSource` stop an overtaken connect from tripping the on-device fallback. The amber/grey status dot can be tapped, and Settings explains it.
- **Privacy policy, landing, support and About** are updated: on-device conversation storage, clipboard use, text mode, and the anonymous install ID used for the speech-minutes limit.

## Mac session: what to do

There is **no iPhone available**, so iOS testing happens in the **iOS Simulator**. A real-iPhone test (mainly cloud speech-to-text, which is live in 1.1.1 but was never hand-tested on iOS) waits until a friend with an iPhone tries it. That's an accepted risk: the app is used mostly by the developer and friends.

1. `git pull`, then `flutter pub get` and `cd ios && pod install`.
2. **Run in the Simulator** (`open -a Simulator`, then `flutter run`) and check:
   - **Text mode end to end.** Copy text in the simulator (for example from Notes or Safari), tap Paste, type a reply, send, and confirm the translation lands on the clipboard (paste it into Notes).
   - **The iOS "Allow Paste" prompt.** iOS asks when an app reads the clipboard. Note how often it appears and whether it's acceptable. If it fires on every Paste and feels bad, possible fixes are a native `UIPasteControl` (iOS 16+) or an `EditableText`-based paste. Discuss with the user before building anything.
   - Layout: the top bar (toggle, cog and Clear pill look balanced), chips with THEM/YOU, bubbles, the composer above the keyboard, and the long-press sheet.
   - Saved conversations survive quitting and relaunching the app.
   - **Voice mode, as far as the simulator allows.** The Simulator can use the Mac's microphone, so cloud STT (`record` package → WebSocket → Deepgram) may work. If it does, that's a useful partial check of the iOS audio path. The on-device fallback (`--dart-define=STT_APP_TOKEN=nope`) may not work in the Simulator; don't chase it.
3. Fix anything iOS-specific, then run `flutter analyze` and `flutter test` (32 tests).
4. **Build and upload:** `flutter build ipa --export-options-plist <plist>` (app-store, manual signing, profile "ConvoGo App Store"), then `xcrun altool --upload-app --type ios -f build/ios/ipa/ConvoGo.ipa --apiKey <KEYID> --apiIssuer <ISSUER>`. The API key (.p8) is in `~/.appstoreconnect/private_keys/`. Keep it **iPhone-only** (`TARGETED_DEVICE_FAMILY=1`). `Info.plist` needs no changes: clipboard access needs no usage string.
5. Commit any fixes and push, so the Windows machine builds Android from the same code.

## After the Mac session

- **Windows:** build the Android AAB (`flutter build appbundle`). Check the path is under `Apps\Translator app\`, not the sibling SportsPort project, then upload it to Play.
- **Store chores (any browser)**, listed in ROADMAP M11:
  - App Store Connect: answer the new age-rating questions, remove China mainland from availability, and update App Privacy (Audio Data, User Content, and Device ID for the anonymous install ID; all App Functionality, not linked, no tracking).
  - Play Console: mirror the same in Data Safety.
  - Both stores: new text-mode screenshots and "What's new" text.
- Then submit both stores for review.

## Working style (reminder)

The user verifies hands-on before committing, does the git commits themselves, and prefers one commit per milestone. The folder is "Translator app" but the repo and package are **talkflip**. Every store release needs a new marketing version (the App Store closes the previous one once it's approved).
