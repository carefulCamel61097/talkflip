# Handoff — 1.2.0 submitted, waiting for store review

**Updated 2026-11-21 on the Windows machine.** Read alongside `CLAUDE.md` (product rules, including text mode) and `ROADMAP.md` → "M11 — Release 1.2.0".

## Where things stand

- **Submitted to both stores on 2026-11-21:** 1.2.0 (build 12). iOS was uploaded from the Mac and is "Waiting for Review". Android was built on Windows and is in Play review. Both stores publish automatically once approved; for iOS, check the "Version Release" setting on the 1.2.0 page.
- **Still live until approval:** iOS 1.1.1 (11) and Android 1.1.0 (10).
- **Store listings updated:**
  - Play: new 1080x2160 screenshots, full and short description rewritten for text mode, release notes, Data Safety (adds Device or other IDs).
  - App Store: 1206x2622 screenshots in the "iPhone with Dynamic Island (Medium display)" slot, What's new, App Privacy (Audio Data, Other User Content, Device ID), new age-rating answers (4+).
  - ConvoGo is now available in the EU on the App Store. It wasn't before, because the trader status was missing; the developer declared "not a trader". China mainland was removed on purpose.
- **Code:** `main` contains everything shipped in 1.2.0, including the Mac's iOS commit `a2111f2` (iOS 15 minimum because Xcode 27 can't build lower, plus Allow Paste hints). Nothing is pending on the Mac except the usual local CocoaPods files, which stay uncommitted.

## What's new in 1.2.0 (for reference)

- **Text mode:** Paste their message, type yours, and the translation is auto-copied. Tap the original or the translation inside a bubble to copy just that part.
- **You on the right in both modes,** with THEM / YOU labels. The prefs key `language_pair_left` still holds *your* language.
- **Conversations are kept on the phone,** one per mode, until the **Clear** pill (with Undo) is tapped. Long-press a bubble to delete it (voice) or copy/delete it (text).
- **Read-back check** (on by default, hidden when it matches what you typed).
- **Faster, race-free side switching:** the mic starts before the cloud connects and buffers the audio, and a session-generation guard stops false fallbacks. The status dot can be tapped, and Settings explains it.
- **Privacy policy, site and About updated:** local storage, clipboard use, text mode, and the anonymous install ID.

## Next

1. **Wait for the reviews.** Respond if either store emails about a problem.
2. **After Android approval:** on the Oppo, uninstall the debug build, leave the internal test program, and install from the Play Store.
3. **When a friend with an iPhone tries it:** test cloud STT on a real iPhone and the Allow Paste flow. See `TESTING_NOTES.md` → "1.2.0: things to watch".
4. **Next release:** bump **both** the marketing version and the build number (e.g. 1.2.1+13). The App Store closes a version's train once it's approved.

## Tooling notes from this release

- **Mac signing:** the keychain holds two "Apple Distribution: Anne Epema" certificates, and the "ConvoGo App Store" profile contains only one (ACE3C29A…). A plain `flutter build ipa` fails until that certificate is pinned. Clean up the extra one some time.
- **Simulator screenshots** are RGBA PNGs, which App Store Connect rejects with a misleading "invalid dimensions" error. Flatten the alpha first.
- **The Oppo's 720x1612 screen** exceeds Play's 2:1 limit. Crop the status and navigation bars down to 720x1440, then upscale to 1080x2160.
- **Cross-machine workflow:** the Mac Claude session can run with Remote Control on, and the Windows session relays to it with SendMessage (the Mac reports back). The user prefers talking only to the Windows session.

## Working style (reminder)

The user verifies hands-on before committing; one commit per milestone. The folder is "Translator app" but the repo and package are **talkflip**. The sibling SportsPort project sits next to it; check AAB paths and the signing key (ConvoGo upload key SHA1 starts `FA:B5`).
