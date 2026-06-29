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

### M10 — Shipping prep (Android shipped; iOS in review)

Release 1.1.0 carries the real mid-speech-switch fix (commit `7cfd7e9`; an `SttService` per-session generation guard that drops stale results — earlier builds 5/6 had an incomplete version that still reproduced live) plus a microphone-permission-flow fix (see below). **Current store state (as of 2026-06-28):**
- **Android: LIVE in production** — build 8 (1.1.0), full roll-out on Google Play since 2026-06-19. Production access was granted after the 14-day / 12-tester gauntlet. Build 8 = the real switch fix (`7cfd7e9`) + the `_ensureMicPermission` restructure. Build 7 (the earlier production candidate) was superseded; build 8 went straight to production. **No Android build 9 needed** — build 9 differs from 8 only by an iOS-only Podfile macro, functionally identical on Android.
- **iOS:** build 9 in App Store review (the `permission_handler` macro fix — see saga below). Not yet released to the App Store as of this writing.
- **Note for the user's own Android device:** to see production build 8 in the Play Store, leave the internal/closed test programs (opt-in links), uninstall, reinstall — enrolled testers are served the test build over production.

Android (Play Store):
- [x] App icon (1024×1024 master at `assets/icon/icon.png`, generated for all densities + Android 8+ adaptive icon via `flutter_launcher_icons`)
- [x] Splash screen (teal `#128C7E` background, icon centered, generated via `flutter_native_splash` — includes Android 12+ `values-v31` setup)
- [x] Privacy policy published at https://carefulcamel61097.github.io/talkflip/ (source in [docs/](docs/), served via GitHub Pages from the `talkflip` repo)
- [x] Upload keystore generated at `C:\Users\Thabi\keystores\convogo-upload-key.jks`, backed up to Google Drive. Password saved in Google Passwords. Gradle wired via gitignored `android/key.properties`. Play App Signing accepted as recovery safety net.
- [x] INTERNET permission added to `AndroidManifest.xml` (debug builds inject this implicitly; release builds don't — caught via internal testing when translation failed instantly)
- [x] Play Console: package name `com.carefulcamel61097.talkflip`, content rating, target audience, data safety form, contact details, store category (Travel & Local), tags (Travel and local, Tools, Productivity, Communication)
- [x] Main store listing: title, short + full description, 512×512 icon, 1024×500 feature graphic, 4 screenshots (chat, picker, settings, about)
- [x] Internal testing release shipped (versionCode 2), translation verified working
- [x] Closed testing: first release sent for Play review 2026-05-20; feature build 1.1.0+5 (Thai + 16 more languages, searchable picker, tap-chip mic-off, free-tier hard stop) sent 2026-06-13. Build 5's mid-speech-switch fix was incomplete (bug still reproduced live) → superseded by build 7 with the real `SttService`-level fix
- [x] Applied for and **granted production access** after the 14-day / 12-tester gauntlet; build 8 promoted to production (full roll-out, live on Google Play 2026-06-19)

iOS (App Store):
- [x] In review: version 1.1.0 (**build 9**), iPhone-only. App Store Connect app id `6779847058`; bundle id `com.carefulcamel61097.talkflip`
- **Microphone permission saga (builds 7→9):** Apple rejected builds 7 and 8 under guideline 5.1.1(iv) + 2.1(a) — the app reached its "Open Settings" dialog *without the native mic prompt ever appearing*. Root cause: `permission_handler` gates each iOS permission behind a **compile-time macro**; the Podfile didn't set `PERMISSION_MICROPHONE=1`, so `Permission.microphone.request()` returned "denied" with no prompt. Fixed in build 9: `ios/Podfile` `post_install` now sets `GCC_PREPROCESSOR_DEFINITIONS` with `PERMISSION_MICROPHONE=1` and `PERMISSION_SPEECH_RECOGNIZER=1` (Podfile is now committed so the macro persists), plus `_ensureMicPermission` always calls `request()` before any Settings dialog. Verified on a clean install — native prompt now appears first. (Android is unaffected by the macro; its permission flow already worked and also got the `_ensureMicPermission` improvement in build 8.)
- [x] Signing: MANUAL App Store distribution (profile "ConvoGo App Store", team `W44P8NT5C6`) — automatic signing fails because the team has no registered devices; mirrors the sibling sportsport-flutter app
- [x] Config: `TARGETED_DEVICE_FAMILY=1` (iPhone-only), `DEVELOPMENT_TEAM` set, `ITSAppUsesNonExemptEncryption=false`; mic + speech-recognition usage strings in Info.plist; icons/splash from the shared `assets/icon/icon.png` master
- [x] App Store metadata: Travel category, 4+ age rating, App Privacy = "Data Not Collected" (translated text services the request only and isn't retained; the Worker stores only an anonymous monthly character count). Support + privacy URLs served from `docs/` GitHub Pages
- Release process (Mac): `flutter build ipa --export-options-plist <plist>` (app-store, manual, profile "ConvoGo App Store") → `xcrun altool --upload-app --type ios -f build/ios/ipa/ConvoGo.ipa --apiKey <KEYID> --apiIssuer <ISSUER>`. App Store Connect API key (.p8) lives on the Mac in `~/.appstoreconnect/private_keys/`

**Cross-store build numbers:** all version name 1.1.0. Android: **production build 8 (live)**. iOS: build 9 in review (builds 7, 8 rejected over the permission flow). The repo/pubspec is at +9. Each store rejects a *duplicate* build number, so the rule stays: **bump the build number for every upload to either store** — next upload anywhere → +10, and keep climbing. iOS must stay iPhone-only.

**Build-machine rule:** Android release AABs must be built on **Windows** (the upload keystore + gitignored `android/key.properties` live there; a Mac-built Android release falls back to the debug key and Play rejects it for wrong signing). iOS is built on the **Mac**. See [convogo-dev-setup] in memory.

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

**Open question:** for languages where `speech_to_text` quality is poor, fall back to cloud STT. Now specced in detail below — see "Language-specific STT (cloud fallback)". Still noted in CLAUDE.md as the per-language STT fallback open question.

### Language-specific STT (cloud fallback)
The native on-device recognizers (`SFSpeechRecognizer` on iOS, `SpeechRecognizer` on Android) vary wildly in quality by language. Two distinct failure modes, which look identical from the outside:
1. **Not available on the device** — e.g. a Thai speaker's phone with no Thai recognition pack catches *nothing*. Fixable by the user/OS; we just need to detect and explain it.
2. **Present but weak** — the model exists but mis-hears, especially with accents or background noise. Only a better model fixes this.

The plan routes weak-language audio to a cloud STT instead of the native engine, keeping native (free, instant, live-streaming) for everything that works well.

**Phase 1 — triage, not a quality fix (cheap, ship first).**
- On activating a side, check the chosen locale against `SpeechToText.locales()`. If absent → show a real hint ("Thai speech recognition isn't installed on this phone — enable it in system settings") instead of silent failure. Handles failure mode #1.
- Add a **static per-language quality tier** (`high` / `medium` / `low`) to the `Language` table, estimated from Whisper's *published* per-language WER (FLEURS / Common Voice benchmarks) — a rough proxy for how much good training audio each language likely had. No runtime measurement; it's an estimate. This tier drives the default engine choice (low → cloud) and lets us point cloud effort only where it's genuinely needed.
- Phase 1 explicitly does **not** fix accuracy — it only rules out the "not available" cause so we know which languages truly need Phase 2.

**Phase 1 — DONE (2026-06-29).** Implemented as `SttService.isLocaleAvailable` (locale list fetched once and cached, matched on the language subtag so any `th_*` counts as Thai) → `ConversationNotifier.isLocaleInstalled` → an `_ensureLocaleAvailable` gate in `conversation_page.dart` that shows a hint and refuses activation only on a confident miss. Plus `SttQuality { high, medium, low }` on every `Language` (low = Arabic, Thai, Malay). Two real-world nuances learned: (1) **web-bypassed** — Chrome's `locales()` under-reports and false-blocked working languages, and web won't ship anyway; (2) on Android the Google recognizer **lists supported languages broadly** (not just downloaded offline packs), so the hint mainly catches "recogniser has no support for this language at all" — common languages like French/Thai correctly pass on a normal device. The tier field is data only; no engine selection is wired yet (that's Phase 2).

**Phase 2 — the actual quality fix (cloud STT).**
- Add an engine selector to the `Language` table (`native` vs `cloud`, via a `cloudStt: true` flag — see freemium note below). The conversation/STT layer picks the engine from the active side's language.
- **Cloud path:** capture raw audio (`record` package) → POST the clip to a new Worker endpoint → return text. Because we have raw audio and *no* STT events, we **detect end-of-turn ourselves** from mic amplitude (silence detection) — the batch completes at the *same moment* a bubble commits today (end-of-turn silence, side-switch, or chip-off), but we own the silence timer instead of borrowing the native engine's `isFinal`.
- **UX trade (Tension 1):** the cloud path is *batch*, not streaming, so cloud-flagged languages lose the live word-by-word draft bubble — it becomes record → "transcribing…" → text. Accepted, because for a language that currently catches nothing, "~1.5–3s late" is strictly better. Native languages keep their instant live bubble untouched.

**Provider options (Tension 2) — latency vs cost vs streaming:**
| Provider | Free? | Latency (short clip) | Streaming (live partials)? |
|---|---|---|---|
| **Cloudflare Workers AI** Whisper (`whisper-large-v3-turbo`) | ✅ ~10k Neurons/day | ~1–3s | ❌ batch |
| OpenAI Whisper (`whisper-1`) | ❌ $0.006/min | ~1–2s (≈ same — latency is model+clip-length bound, not host) | ❌ batch |
| Groq (hosted Whisper turbo) | ❌ paid | often sub-second (fastest) | ❌ batch |
| Deepgram / AssemblyAI | ❌ paid | low | ✅ restores the live draft bubble |

**Decision: start with Cloudflare Workers AI Whisper** — we already run the Worker, it has a free daily tier, the API key stays server-side, and it fits the "stay free" constraint. Paying buys accuracy parity (OpenAI) or speed (Groq) or live streaming (Deepgram), none of which is worth breaking "free" for the first cut. This maps cleanly onto the freemium idea: free native languages, paid cloud languages.

**Freemium boundary (write-down of "Worker first, freemium later"):** the `cloudStt` flag does double duty — it's both the engine selector *and* the eventual paywall line. Native (on-device, free to us) languages stay free; cloud-STT languages (which cost us Neurons/credits) become the premium tier later. So the architecture we build now for quality already draws the monetisation boundary, no rework. See Monetisation below.

**Open questions:** which languages get flagged `cloud` (driven by Phase 1's tier + real tester feedback, e.g. Thai); whether to ever fake streaming by chunking Whisper (deferred — fiddly, burns far more Neurons); whether a noisy environment alone (not language) should trigger cloud.

**Phase 2 — DONE, but built differently than specced above (2026-06-29).** Hands-on testing on the Oppo showed the native on-device STT is worse than Google Translate's even for **English** (Chrome felt good only because its Web Speech API *is* Google's cloud STT). So cloud STT became the **primary engine for all languages**, not a per-language fallback — and we chose **Deepgram streaming**, not batch Whisper, specifically to **keep the live word-by-word draft bubble** (the locked UX principle batch would have broken). Provider picked Deepgram over Google Cloud STT purely on build difficulty (WebSocket relay vs gRPC+OAuth); both clear the quality bar, Deepgram covers Thai on Nova-3.

Architecture (all behind one seam so the UI is untouched): `SttEngine` interface with `OnDeviceSttEngine` / `CloudSttEngine`, chosen by `AppConfig.useCloudStt` (now `true`). `MicAudioSource` (`record` pkg) streams PCM16/16k/mono to a Worker `/stt-stream` WebSocket relay → Deepgram (key server-side); Deepgram's interim results drive the bubble, `speech_final` commits. Validated on Oppo: live bubble, accuracy, and pause-handling all good.

**Commit cadence (step 7).** A turn commits on the *first* of three signals, so the bubble can never hang: (a) `speech_final` (~300ms, Deepgram's acoustic VAD), (b) `UtteranceEnd` (~1s, Deepgram's word-gap timer via `utterance_end_ms=1000` — fires even when background noise keeps the VAD hot), (c) a **3s client-side hard ceiling** in `CloudSttEngine` that commits the on-screen draft unconditionally. (a)/(b) are noise-sensitive guesses; (c) trusts neither and guarantees termination — mirrors the on-device engine's silence timer.

**Accepted behavior (don't "fix"):** switching sides mid-sentence drops the last ~few-hundred-ms of speech, because we commit the last partial *received* and streaming lags real speech by the network round-trip. Deemed reasonable UX ("let the bubble finish, then switch") and far better than the old wrong-side bug. Recovering the tail would need a finalize-and-wait on switch — added latency + straggler risk, not worth it.

**Remaining polish:** ~~(7) resilience~~ **DONE (2026-06-29):** `ResilientSttEngine` decorator wraps cloud + on-device; on a cloud `onError` (connect refused, mid-session drop, mic fail) it transparently restarts the same turn on `OnDeviceSttEngine`, flips `sttModeProvider` to `fallback` (subtle amber "basic speech recognition" dot, shown only when online so it never collides with the offline dot), and reconnects lazily per-turn — gated by connectivity (skip cloud when offline) and a 30s post-failure cooldown. Plus the commit-cadence fix above. — ~~(8) privacy label~~ **repo side DONE (2026-06-29):** privacy policy (`docs/privacy.html` live + `docs/index.md`) and in-app About (`about_page.dart`) now disclose that microphone audio is streamed off-device to Deepgram (via the Cloudflare proxy) for transcription, with the on-device recognizer as an offline fallback; the old "audio never leaves the device" claim is gone. iOS usage strings unchanged (still accurate; speech-recognition permission still needed for the fallback). **Store side pending at next submission:** App Store Connect *App Privacy* must move off "Data Not Collected" to disclose Audio Data + User Content (text), used for App Functionality, not linked to identity, no tracking; mirror in Google Play *Data Safety*. — ~~(9) per-device minute counting~~ **DONE (2026-06-29):** the Worker meters uploaded audio (32000 B/s → seconds) into KV keyed `mins:<device>:<month>` + `mins:global:<month>`, flushing every ~2 min and on close. Caps: **120 min/device/month**, **2000 min/month global**; over either → the `/stt-stream` upgrade is refused, which trips the on-device fallback (degraded, not dead). The public endpoint is gated by a shared `STT_APP_TOKEN` (app-side default in `config.dart`, overridable via `--dart-define`; Worker secret must match) — a spoofable speed-bump, the caps are the real guard. An anonymous per-install `device` id (random, in prefs) attributes usage. Verified on Oppo: device + global counters climb together. **Freemium hook:** the same per-device minute counter is what a future free-quota → top-up model reads. Then a new build to ship.

**Freemium boundary shift:** the original "free native languages, paid cloud languages" split (the `cloudStt`-per-language flag) **no longer applies** — cloud is now the only engine. Monetisation becomes a **metered cloud-minutes** model instead (free quota → top-up), which is exactly what the usage-transparency note under Monetisation describes.

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
2b. **Free native languages, paid cloud-STT languages.** Falls straight out of the "Language-specific STT (cloud fallback)" architecture above: on-device STT languages (free to us) stay free; languages that need cloud STT (which costs us Neurons/credits) become the premium tier. The `cloudStt` flag *is* the paywall line, so no extra plumbing. Most natural fit alongside model 1 — quota for free languages, unlock for the cloud ones.
3. **"Pay what you want" / tip jar.** Friction-free but unreliable revenue. Worth considering as a low-effort addition alongside another model.
4. **Ads.** Rejected. Conflicts with "smooth and fast > feature-rich" and the no-tracking privacy story.

**Usage transparency before the paywall (UX principle).** A top-up prompt like "500 minutes for $3" is meaningless to a user with no frame of reference for how many minutes *they* actually use. Before (and at) the paywall, show the user their **own past usage in minutes** and a running **"would-have-cost"** figure — i.e. what their usage so far would have cost at the pay rate. This lets them calibrate the offer against their real behaviour ("oh, I've used 40 minutes this month, so a 500-minute pack is months of use") instead of guessing. Reinforces the trust/no-dark-patterns posture: we're showing you what you use and what it costs, not just asking for money. The per-device usage counter the Worker already maintains is the data source. Note billing realities: app-store IAP sells discrete products (subscriptions or consumable minute-packs), not a live per-minute meter — so "metered" pricing is approximated with credit packs, and Apple/Google handle the payment (no credit card touched by us; ~15% cut under ~$1M/yr, 30% above).

**Open questions:** what's the trigger — the 500k Google free-tier cap, $X/month in costs, or earlier (so growth can be funded)? Per-device tracking integrity (people can reinstall). iOS and Android billing differences.

### Messaging mode (text-only sibling app)
A separate, STT-free version: a bilingual messaging app. Each person types in their own language; every message shows both the **original** (sender's language) and the **translation** (recipient's language) — the same dual-text bubble ConvoGo already uses. No microphone, no speech recognition.

**Why it's appealing:**
- Reuses the existing translation infrastructure (Worker + Google Translate) directly; the dual-text bubble UI carries over unchanged.
- Drops all the STT complexity (mic permissions, platform recognizer quirks, the Android session-gap problem, per-language STT quality).
- Works in contexts where speaking is awkward or impossible (quiet rooms, async conversations, accessibility for deaf/hard-of-hearing users).

**Why it's significant scope:**
- It breaks the "two people, one phone, one moment" model — this is **two devices, remote, asynchronous**, which means a real messaging backend: identity/accounts, real-time delivery, message persistence, push notifications. That's a much larger build than the current serverless-proxy setup, and it's where most of the cost/effort lives.
- Translation volume scales with message count across many users → the free-tier cap math (see Monetisation) becomes more pressing.

**Open question:** is this a mode inside ConvoGo or a separate product sharing the translation infrastructure? Almost certainly a separate product — the networking/accounts layer is a different beast from the current one-phone app.

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
