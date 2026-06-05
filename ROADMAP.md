# Build Order

Sequenced milestones for getting from greenfield to beta-ready. Each milestone is small enough to ship/test in isolation, with a clear demo state.

See [CLAUDE.md](CLAUDE.md) for product principles and locked decisions.

## Critical path

M0 → M1 → M2 → M3 → M4 is the spine. After M4 the product functions end-to-end and two people can actually have a translated conversation; M5–M8 add the polish and completeness. M5–M8 can be reordered if needed, but the spine order maximises "feels real" as early as possible. M4 carries the highest risk (provider keys, Worker setup, billing) — handling it right after M3 surfaces any provider issues early.

## Milestones

### M0 — Project scaffold ✓
- [x] `flutter create` in the project folder (bundle ID: `com.carefulcamel61097.talkflip`)
- [x] Add dependencies: `flutter_riverpod`, `dio`, `shared_preferences`, `speech_to_text`, `permission_handler`, `intl`, `connectivity_plus`
- [x] Folder structure: `lib/features/conversation/`, `lib/features/settings/`, `lib/core/`
- [x] iOS `NSMicrophoneUsageDescription` (Info.plist) + Android `RECORD_AUDIO` (manifest)
- [x] Riverpod `ProviderScope`, baseline theme
- [x] Web platform added for dev convenience (won't ship)

**Demo:** empty themed screen runs in Chrome. Mobile verification deferred until M3 (Android Studio emulator or physical Android device).

### M1 — Static layout with mock data ✓
- [x] Top bar with centered settings cog
- [x] Language chip row (hardcoded EN / ES)
- [x] Chat area with mock dual-text bubbles (a few on each side)
- [x] Mock draft bubble (faded, solid border for now — dashed deferred to avoid extra dep)
- [x] Active-side highlight visible; inactive side fully readable (no dimming)

**Demo:** static screenshot-quality mock of the final UI, verified in Chrome.

### M2 — Activation state (tap chips) ✓
- [x] Riverpod state: `ActiveSide { neutral, left, right }` via `NotifierProvider`
- [x] Tap chip activates that side
- [x] Bubbles, chips, and draft bubble all react to state
- [x] No STT yet — purely visual state machine
- [x] Bubble border always 2px (only colour toggles) to prevent layout shift on activation change

**Demo:** can flip active side by tapping chips; visual is fully reactive and stable.

### M3 — Speech-to-text into draft bubble ✓
- [x] `speech_to_text` integration via custom `SttService` wrapper
- [x] Mic permission flow on first need (handled internally by `speech_to_text`)
- [x] Partial results stream into draft bubble live
- [x] 3s intra-turn silence commits via our own timer (platform `isFinal` is unreliable — Android too aggressive, Web never fires; our timer overrides)
- [x] Switching sides also commits any pending draft
- [x] Continuous listening with auto-restart across Android session boundaries; 500ms backoff after STT errors to prevent tight restart loops
- [x] iOS `NSSpeechRecognitionUsageDescription` and Android `RecognitionService` queries entry added

**Demo:** verified on Chrome (web) and Android (physical Oppo CPH2483). One-sided conversation where speech becomes bubbles in the active side's language. Translation placeholder `"..."` will be replaced with real translation in M4.

### M4 — Cloudflare Worker proxy + Google Translate ✓
- [x] CF Worker: `POST /translate {text, source, target}` → Google Translate API → response. API key in Worker secret.
- [ ] ~~Device-ID-based rate limiting (KV-backed counter)~~ — deferred. GCP API restriction + free-tier cap bounds damage; revisit if abuse becomes a concern.
- [x] Flutter calls the Worker on bubble commit via `dio`
- [x] Update bubble with translation when response arrives (in-place by message ID)
- [x] Translation failure → "tap to retry" affordance on the bubble (refresh icon + tappable bubble)

**Demo:** verified end-to-end on Chrome (web). Real speech → real translation, draft → bubble with `…` → translation appears within a few hundred ms. Android also functional, but with a known session-gap STT limitation documented in [CLAUDE.md](CLAUDE.md).

**Worker URL:** `https://talkflip-translator.talkflip.workers.dev` (public-facing; GCP key is in Cloudflare secret store).

### M5 — Swipe gesture ✓
- [x] `GestureDetector` with `onHorizontalDragEnd` wrapping the body (`HitTestBehavior.translucent` so chip taps and ListView scroll still work)
- [x] Direction convention: **carousel/page-swipe** — swipe pushes the current side away, revealing the opposite side (swipe right → activate left; swipe left → activate right). Matches dominant app conventions (Instagram, Tinder, iOS Photos, etc.). Changed from the original "swipe toward target" after user testing showed the carousel direction is more intuitive.
- [x] Velocity threshold (300 px/s) to avoid accidental triggers
- [x] Vertical drags still scroll history (handled by the inner `ListView` — gesture arena disambiguates by direction)
- [x] Auto-scroll chat to bottom on new messages and draft updates (folded in — was missing since M3)

**Demo:** one-handed thumb-swipe between sides; chat auto-scrolls to follow the latest content.

### M6 — Persistence + first-launch language picker ✓
- [x] `shared_preferences` stores the language pair via `LanguageRepository` + `LanguagePairNotifier` (AsyncNotifier)
- [x] No stored pair → language picker screen → user selects two → persisted → main page
- [x] Stored pair → straight to main page (routing via `_AppRouter` in `main.dart`)
- [x] Language list = curated 13-language list (`SupportedLanguages.all`) chosen as the intersection of common `speech_to_text` locales + Google Translate supported codes
- [x] Picker labels: "Your language" / "Other language" (matches the WhatsApp convention where left/green bubbles are "yours")
- [x] Continue button disabled until both languages are selected AND they're different
- [x] `ConversationNotifier` reads STT locale + Google Translate codes from the persisted pair; chips display the persisted labels

**Demo:** fresh install (or cleared site data on Chrome) → picker → continue → conversation page with the picked pair. Reload → straight to conversation page.

### M7 — Settings page ✓
- [x] Settings route accessible from the cog (cog is an `IconButton` that pushes `SettingsPage`)
- [x] Change languages — reuses `LanguagePickerPage` in "edit" mode (pre-filled with current pair, AppBar with back, "Save" button). After save, `Navigator.popUntil(isFirst)` returns straight to the conversation (skipping the settings page).
- [x] Clear current conversation — confirmation dialog → `ConversationNotifier.clearMessages()` → pops back to conversation
- [x] About / privacy policy — static page with app description and brief privacy text
- [x] Default translation font bumped 18→20sp (free accessibility win; configurable text-size control deferred to M9)
- [x] Swipe velocity threshold lowered 300→200 (better Chrome mouse-drag experience; touch flicks well above either threshold)

**Demo:** verified on Chrome. All three settings actions work; language change pops back to conversation; clear wipes messages and pops back; about page renders.

### M8 — Status indicators + onboarding + mic suspend ✓
- [x] Offline indicator via `connectivity_plus`: grey dot in top-right of the top bar when offline; nothing when online. Tooltip explains "Offline — translation unavailable". Note: Chrome's DevTools "Offline" simulation does not trigger this (it only blocks HTTP, doesn't update `navigator.onLine`); verify by actually disconnecting Wi-Fi.
- [x] Mic suspend: 60s of no new speech → `SttService` stops listening and emits `onSuspended` → `ConversationNotifier` returns to `ActiveSide.neutral`. The visual transition (chips going from active to outlined) IS the user-facing signal. Explicit "tap a side to start" hint deliberately skipped — clutter outweighs benefit since the neutral state is already a familiar visual.
- [x] First-launch swipe onboarding: SnackBar saying "Tap a language to talk. Swipe sideways to switch sides." appears on first arrival to the conversation page, auto-dismisses after 5s. Persisted via `seen_swipe_hint` flag in `shared_preferences`.

**Demo:** offline dot toggles with real network state; mic auto-suspends after 60s; snackbar shows once on first launch.

### M9 — Code polish before testers ✓
- [x] Mic permission denied flow — `_ensureMicPermission` checks status, requests if `denied`, falls back to an "Open Settings" dialog if permanently denied. Chip taps and swipes go through this gate before activating.
- [x] Rename TalkFlip → ConvoGo (user-facing brand). Technical identifiers (`talkflip` repo / package / bundle ID / Worker URL) kept stable. See "A note on naming" in [README.md](README.md).
- [ ] *(Deferred to [TESTING_NOTES.md](TESTING_NOTES.md))* — animation refinement, active-side highlight clarity, translation-on-offline-first-launch edge case, language picker validation, "Larger text" accessibility toggle. These are all "wait and see what real users say" rather than design-blind.

**Demo:** denying mic permission produces a clear dialog with a path to system settings; granting it from settings restores normal operation. App name ConvoGo throughout.

### M10 — Shipping prep (in progress)

Android side is in motion; iOS deferred (will pick up on the Mac when ready).

Android (Play Store):
- [x] App icon (1024×1024 master at `assets/icon/icon.png`, generated for all densities + Android 8+ adaptive icon via `flutter_launcher_icons`)
- [x] Splash screen (teal `#128C7E` background, icon centered, generated via `flutter_native_splash` — includes Android 12+ `values-v31` setup)
- [x] Privacy policy published at https://carefulcamel61097.github.io/talkflip/ (source in [docs/](docs/), served via GitHub Pages from the `talkflip` repo)
- [x] Upload keystore generated at `C:\Users\Thabi\keystores\convogo-upload-key.jks`, backed up to Google Drive. Password saved in Google Passwords. Gradle wired via gitignored `android/key.properties`. Play App Signing accepted as recovery safety net.
- [x] INTERNET permission added to `AndroidManifest.xml` (debug builds inject this implicitly; release builds don't — caught via internal testing when translation failed instantly)
- [x] Play Console: package name `com.carefulcamel61097.talkflip`, content rating, target audience, data safety form, contact details, store category (Travel & Local), tags (Travel and local, Tools, Productivity, Communication)
- [x] Main store listing: title, short + full description, 512×512 icon, 1024×500 feature graphic, 4 screenshots (chat, picker, settings, about)
- [x] Internal testing release shipped (versionCode 2), translation verified working
- [ ] Closed testing release: sent for Play review on 2026-05-20 (the 14-day-12-tester gauntlet must complete before production access unlocks)
- [ ] Post-internal UX additions (tap-anywhere-in-chat to switch sides, active-side dot above chip, TalkFlip→ConvoGo typo fix in mic dialog + iOS Info.plist) are committed but **not yet built into a v3 AAB** — will bundle with tester feedback when v3 ships
- [ ] Apply for production access after the 14-day gauntlet completes

iOS (App Store):
- [ ] All work deferred to the Mac. App icon / splash assets generate from the same `assets/icon/icon.png` master via the same tooling. iOS bundle metadata (`CFBundleDisplayName`, `CFBundleName`) already updated to ConvoGo. `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` already in Info.plist.

## Beyond v1.0 — post-launch ideas

Captured here so they don't get lost. None are committed; each will need a design pass before it becomes a milestone. Listed in rough order of how "free" they feel — language expansion is mostly mechanical, monetisation needs a strategy decision, videocall mode is a real product redesign.

### More languages
~31 languages, gated on the intersection of Apple `SFSpeechRecognizer` published locales (the stricter STT platform) and Google Translate codes. See `SupportedLanguages.all` in `lib/core/supported_languages.dart`. One STT locale per language.

**To add more, per language:**
- Verify the locale is in `speech_to_text` (varies by platform — iOS and Android have different lists).
- Verify the language has a Google Translate code (almost always yes).
- Add a `Language` entry to `SupportedLanguages.all` in `lib/core/supported_languages.dart`.
- Test that real speech in that language gets transcribed accurately enough to be useful — quality varies wildly (some Indian languages, some African languages, less-common European ones).

**Confidence without manual testing:** rather than spot-test each language, gate the list on the platform vendors' *published* STT support — Apple's `SFSpeechRecognizer` supported locales (the stricter platform) intersected with Google Translate. Anything Apple lists is very likely also supported by Android/Google. This yields ~31 languages we can trust on most devices with zero hand-testing.

**Future — device-driven list (Option B):** instead of a static list, build the picker at runtime from the device's *actual* STT locales (`SpeechToText.locales()`) ∩ Google Translate. Self-curating and honest — each phone only shows what it can really transcribe — and it makes the iOS-vs-Android coverage gap (e.g. Albanian) disappear automatically. Deferred because the per-device-varying list needs careful UX and more language metadata, but it's the elegant long-term answer.

**Open question:** for languages where `speech_to_text` quality is poor, fall back to cloud STT (Whisper via a Worker endpoint, or Google Cloud Speech). This is noted in CLAUDE.md as the per-language STT fallback open question.

### Romanization of non-Latin scripts
Optional Settings toggle (off by default) to show Latin-alphabet transliteration alongside the translation for scripts like Thai, Japanese, Korean, Chinese, Russian, Arabic, Hindi (e.g. สวัสดี → *sawatdi*). Serves "read, don't listen" (a traveler who can't read the script can't use the output) and doubles as a language-learning aid.

**Status: DEFERRED (2026-06).** Researched and parked — no option clears the minimalist + free bar. Google's official `romanizeText` (v3) doesn't support Thai, Chinese, or Korean (and needs service-account OAuth); there's no usable on-device Dart romanizer; hand-rolling RTGS is real work; and the only free Thai path is the unofficial `translate_a/single` endpoint, which is too fragile/ToS-gray to ship.

**Revisit when** a single decent, free, low-effort option covers **Thai, Chinese, Japanese, and Korean** (the non-Latin scripts that matter for this app) — e.g. ML Kit gaining romanization, a maintained Dart library, or accepting the unofficial endpoint for a non-production build.

**Tracked in:** [issue #1](https://github.com/carefulCamel61097/talkflip/issues/1).

### Monetisation
ConvoGo currently has no revenue model. Translation costs accrue on the free tier of Google Cloud Translation (500k chars/month) — fine for now, but a problem at scale.

**Plausible models, in order of how well they fit the product:**
1. **Per-device monthly free quota → optional unlock.** Most natural for ConvoGo. Track usage on the device (or via Worker counter keyed by device ID), show a soft prompt once a user hits, say, 50k chars in a month, offering a one-time or monthly unlock. Travellers using it for a one-off trip never see the prompt; heavy users self-select into paying.
2. **One-time paid unlock for "everything."** Single in-app purchase that removes any limits. Cleaner UX (no recurring billing), familiar pattern for travel apps.
3. **"Pay what you want" / tip jar.** Friction-free but unreliable revenue. Worth considering as a low-effort addition alongside another model.
4. **Ads.** Rejected. Conflicts with "smooth and fast > feature-rich" and the no-tracking privacy story.

**Open questions:** what's the trigger — the 500k Google free-tier cap, $X/month in costs, or earlier (so growth can be funded)? Per-device tracking integrity (people can reinstall). iOS and Android billing differences.

### Videocall mode
Currently ConvoGo is built for the "two people, one phone, face-to-face" moment. A natural adjacent use case: two people on a video call, each speaking their own language, ConvoGo running on one side and translating the other side's audio in real time.

**Why this is interesting:**
- The two audio streams are already separated by the call (incoming = other person, outgoing = you), which means no manual chip-tap to switch sides — the app could auto-attribute speech.
- Removes the "one phone" constraint, expanding to remote international conversations.
- Captures a different audience: business calls, family abroad, online dating across languages.

**Why it's significant scope:**
- Audio routing during an active call is OS-level complex (Android `AudioPlaybackCapture`, iOS no clean equivalent without an extension).
- Either integrate with existing call apps (Zoom, FaceTime, WhatsApp, Google Meet — each different) or build ConvoGo's own call layer (huge scope creep).
- Significantly changes the product's core principle from "two people, one phone, one moment" → potentially a different product entirely.

**Open question:** is this an add-on to ConvoGo, or a sibling product sharing the translation infrastructure? Probably the latter, since the UX is so different.
