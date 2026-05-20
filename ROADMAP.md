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

### M9 — Code polish before testers
- [x] Mic permission denied flow — `_ensureMicPermission` checks status, requests if `denied`, falls back to an "Open Settings" dialog if permanently denied. Chip taps and swipes go through this gate before activating.
- [ ] *(Deferred to [TESTING_NOTES.md](TESTING_NOTES.md))* — animation refinement, active-side highlight clarity, translation-on-offline-first-launch edge case, language picker validation, "Larger text" accessibility toggle. These are all "wait and see what real users say" rather than design-blind.

**Demo:** denying mic permission produces a clear dialog with a path to system settings; granting it from settings restores normal operation.

### M10 — Shipping prep (when ready)
Not started; out of scope until you actually want to release. Includes:
- App icon and splash screen graphics
- Apple Developer account + Mac with Xcode for iOS builds
- Google Play Developer account
- TestFlight + Google Play internal track setup
- App store listings (screenshots, descriptions, privacy policy URL)
