# Real-user testing checklist

Items deferred from milestones (M9 in particular) to be revisited once we have real users testing the app on their own devices. Each one was either "probably fine" or "won't know until we see it in the wild" — the right call is to gather real-use data before spending effort.

## Bugs / edge cases to verify

- **Translation failure on first launch when offline.** `connectivityProvider` is a `StreamProvider` — there's a brief window between app mount and the first connectivity result. If the user immediately speaks during that window while actually offline, the bubble may attempt translation and fail. Check whether this happens in practice and whether the existing "tap to retry" affordance covers it.
- **Language picker error states.** Currently the Continue button disables when no language is picked or both are the same — that covers the main cases. Test for: rapidly switching the same dropdown value, network drop during save, etc.

## Polish items to gather feedback on

- **Active-side highlight clarity.** Reinforced post-internal-testing: a 12px accent-coloured dot now sits above the active language chip, on top of the existing 2px teal border around active bubbles and the chip's filled teal. Watch whether this combination is now obvious enough at a glance, especially for older / less tech-fluent users. If still unclear, options: stronger color, a side-strip indicator down the screen edge, or a subtle background tint on the active half.
- **Tap-anywhere-in-chat discoverability.** Added post-internal-testing. Tapping anywhere in the chat now toggles the active side (failed-translation bubbles still intercept for retry). Watch whether new users discover this naturally — the swipe gesture was the original "discoverability gap." If tap-in-chat works, the swipe hint snackbar text can probably be retired entirely.
- **Animation refinement.** No animations currently on chip activation, bubble entry, or side transitions. Worth observing whether the lack feels abrupt or whether it actually feels appropriately fast/snappy. Possible additions: subtle bubble fade-in on commit (~150ms), chip color crossfade on activation, smooth scroll behavior already in place.
- **Larger text accessibility toggle.** Translation font is currently 20sp (bumped up from 18sp in M7). For elderly "other side" users, this may still be too small. Decide between a binary "Larger text" toggle vs. a slider once we see how often it's actually needed and how much bigger users want it.
- **Albanian (SQ) speech-to-text coverage.** Added alongside Thai. Translation *to* Albanian works fine. Speech-*in* depends on the platform recognizer: on Android, `speech_to_text` routes through Google's `SpeechRecognizer` (the same engine Google Translate uses), so Albanian transcription will likely work; on iOS it uses Apple's `SFSpeechRecognizer`, which probably lacks Albanian. Verify Albanian speech-in on a real Android device, and confirm the iOS behavior (graceful fallback vs. silent failure) when we have an iOS tester. Whisper cloud-STT fallback is the eventual fix if iOS can't do it. Thai (`th_TH`) is well supported on both platforms.
- **Mic permission denied flow UX.** Added in M9 — verify the dialog reads clearly, that "Open Settings" actually lands on the right OS settings page on each platform, and that the user successfully recovers after granting permission and returning to the app.

## Process notes

When you start gathering real-user feedback, treat each item here as a separate ticket. Don't try to fix all of them in one pass — most will turn out to be fine, and the ones that aren't will tell you what they actually need rather than what we guessed.
