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

### M3 — Speech-to-text into draft bubble
- [ ] `speech_to_text` integration
- [ ] Mic permission flow on first need
- [ ] Partial results stream into draft bubble live
- [ ] 2–3s intra-turn silence commits to a finalised bubble (original text only; translation field = `"..."` placeholder)
- [ ] Switching sides also commits any pending draft

**Demo:** one-sided conversation where speech becomes bubbles in the active side's language.

### M4 — Cloudflare Worker proxy + Google Translate
- [ ] CF Worker: `POST /translate {text, source, target}` → Google Translate API → response. API key in Worker secret.
- [ ] Device-ID-based rate limiting (KV-backed counter) to prevent abuse
- [ ] Flutter calls the Worker on bubble commit via `dio`
- [ ] Update bubble with translation when response arrives
- [ ] Translation failure → "tap to retry" affordance on the bubble

**Demo:** real speech → real translation. Two people can actually converse.

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
