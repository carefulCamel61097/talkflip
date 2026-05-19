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

### M5 — Swipe gesture
- [ ] `GestureDetector` with `onHorizontalDragEnd`
- [ ] Direction convention: swipe in the direction of the side you want to activate (swipe-left → left chip; swipe-right → right chip)
- [ ] Threshold + velocity check to avoid accidental triggers
- [ ] Vertical drags still scroll history

**Demo:** one-handed thumb-swipe between sides.

### M6 — Persistence + first-launch language picker
- [ ] `shared_preferences` stores the language pair
- [ ] No stored pair → language picker screen → user selects two → persisted → main page
- [ ] Stored pair → straight to main page
- [ ] Language list = intersection of `speech_to_text` supported locales + Google Translate supported targets

**Demo:** fresh install picks languages once; relaunch goes straight to conversation.

### M7 — Settings page
- [ ] Settings route accessible from the cog
- [ ] Change languages (reuses M6 picker)
- [ ] Clear current conversation (with confirmation)
- [ ] About / privacy policy (static)

**Demo:** all settings actions work; languages and conversation state behave correctly afterward.

### M8 — Status indicators + onboarding + mic suspend
- [ ] Offline indicator via `connectivity_plus`: grey/muted-orange dot near settings cog when offline; nothing when online
- [ ] Mic suspend: 60s total silence on active side → return to neutral + show "tap a side to start" hint
- [ ] First-launch swipe onboarding: one-time animation on the chips, dismissed after first successful swipe

**Demo:** all status states behave correctly under offline / silence / first-launch conditions.

### M9 — Pre-ship polish
- [ ] Animation refinement (chip activation transitions, bubble entry)
- [ ] Edge cases: permission denied flow, no internet on first launch, language picker error states
- [ ] App icon, splash screen
- [ ] TestFlight + Google Play internal track setup

**Demo:** ready for beta testers.
