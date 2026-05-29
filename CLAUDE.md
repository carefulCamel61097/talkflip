# ConvoGo

A hyper-minimalist, two-person, face-to-face translation app. One phone, two languages, zero friction.

## Core principles

These guide every product and engineering decision. When in doubt, refer back here.

1. **Two people, one phone, one moment.** The entire UX is optimized for two humans standing face-to-face, passing a single phone back and forth. Features that don't serve that situation are out of scope.
2. **Minimal interactions per turn.** A speaker should start a turn, deliver it, and end it without pressing any explicit "record" or "stop" button. Handing the phone over is the only signal we need.
3. **Read, don't listen.** Text is faster than synthesized speech, works in noisy environments, and avoids robot voices. No TTS.
4. **Discoverability AND elegance.** Gestures are powerful but invisible. Every primary action must also have a visible, tappable affordance. Gestures are a faster shortcut, never the only path.
5. **Always show both sides.** Both speakers' transcripts are visible at all times. Indicate the active speaker by highlighting their bubbles, never by hiding or dimming the other side.
6. **Smooth and fast > feature-rich.** Any feature that adds latency, taps, or visual clutter must justify itself against these principles.
7. **One-handed operation.** The typical user is a traveler holding the phone in one hand, pointing it at the other person. Both sides must be activatable with a single thumb. Physical hand-off is NOT the primary mode of switching — pointing-and-swiping is.

## Locked design decisions

### Layout

**Single main page.** The app has exactly one in-conversation screen. Settings and onboarding live elsewhere.

Anatomy of the main page, top to bottom:
1. **Top bar:** small, low-contrast settings cog centered at the top. Preserves left/right symmetry of the chips below. Connectivity indicator (see below) lives in this bar when relevant.
2. **Language chips row:** two language-code chips (EN, ES, etc.), one on the left, one on the right, each above their own side of the chat area. Chips are the primary tappable affordance to activate their side.
3. **Chat area:** chronological, WhatsApp-style. Left-side language's bubbles align left; right-side language's bubbles align right. Vertical scrolling reviews history.
4. **Active speaker's draft bubble:** rendered inside the chat area on the active side, dashed/faded, streaming live transcription as the speaker talks. On commit (silence threshold OR side switch), the draft graduates into a committed dual-text bubble.

**Dual-text bubble:** original transcribed text in small, dimmed font (so the speaker can verify accuracy); translated text directly below in large, bold font (for the listener).

**No fixed bottom strip.** The draft lives inside the chat area, not in a dedicated bottom input zone (rejected because it breaks "both sides always visible" symmetry and pulls the speaker's eye away from their own chat side).

**Both sides always visible.** Even when one side is active, the inactive side's bubbles remain fully readable. Active state is shown by highlight on the active side, never by dimming the inactive side.

### Speaker switching
- **No "end recording" button.** Switching to the other speaker is the implicit commit.
- **Primary affordances (two, both discoverable):**
  - Tap a language chip at the top. The most explicit affordance — picks a specific side.
  - Tap anywhere in the chat area. Toggles the active side (left ↔ right), or activates the user's side from neutral. The most universally discoverable interaction — users naturally try tapping the chat. Failed-translation bubbles still win the tap for retry; successful bubbles pass through.
- **Secondary (shortcut):** horizontal swipe (carousel direction) does the same thing. Faster once learned, but never the only way.
- **Active-side indication (two unified cues):**
  - A 12px accent-coloured dot above the active language chip — same colour as the bubble border highlight. Familiar "online" indicator pattern; immediately glanceable.
  - A 2px accent-coloured border around the active speaker's bubbles. Border is always rendered at 2px (only the colour toggles, transparent when inactive) so activation never shifts layout.
  - Do NOT dim the inactive side — both stay fully readable.
- **Optional accent:** subtle background color shift on the active side. Both-side text contrast must remain unaffected.

### Microphone behavior
- **Continuous listening on the active side.** Mic stays open until the other side is activated, or until a longer silence suspends it (see below).
- **Intra-turn silence threshold.** Bubble commits when *either* (a) the platform STT engine fires `isFinal=true` (Android ~1s; iOS/Web rarely from natural pauses) *or* (b) our 3s fallback silence timer fires. Net effect: Android commits on ~1s sentence-end pauses (matching its native VAD); iOS and Web commit on 3s. Not used to switch speakers — switching is always explicit.
- **Neutral state.** Neither side is active. Reached on app open before first interaction, after a longer total silence (e.g., 30–60s, battery-saving), or after a deliberate "stop" gesture (TBD if needed).
- **Activating from neutral.** Tapping a language chip OR swiping horizontally must activate the corresponding side. Swipe must work in neutral state, not only when switching between two active states.
- **Live draft bubble.** Words stream in real-time in a faint bubble as the speaker talks. On commit (silence threshold OR side switch), the draft is finalized and translated.

### Language identifiers
- **Language codes (EN, ES, FR, …) as tappable chips.** Flags rejected for now — politically and linguistically lossy (🇺🇸 ignores UK/AU English, 🇪🇸 ignores Latin American Spanish, 🇨🇳 vs 🇹🇼 is a minefield). Revisit if users push back.

### Gestures
- **Horizontal swipe:** switch speakers OR activate a side from neutral state. **Direction convention: carousel/page-swipe model** — swipe pushes the current side off-screen and reveals the opposite side (swipe right → activate left; swipe left → activate right). Matches Instagram stories, Tinder, iOS Photos, etc. Must be reachable by a single thumb (works from the lower half of the screen at minimum).
- **Vertical swipe:** scroll conversation history.
- No other gestures in MVP.

### Persistence
- **Persistent language memory.** The two chosen languages persist across sessions. Reopening drops users straight into the conversation screen in under a second.
- **No conversation history persistence.** Conversations are in-memory only and clear on app close. Fresh conversation every session matches the "two people in a moment" use case.

### Settings page

Settings is reachable via the cog in the top bar. Contents:
- **Change the two languages.** This is the primary reason to enter settings.
- **Clear current conversation.** For wiping mid-session without closing the app.
- **About / privacy policy.** Required for app stores.

Nothing else. Silence threshold, mic timeout, STT engine choice, etc., are NOT exposed to users in MVP.

### Status indicators

- **Connectivity:** no indicator when online (a green "all good" dot would be visual noise). When offline, a subtle grey/muted-orange dot appears near the settings cog, optionally with a small "offline" label that fades in on the transition. Red is too alarming for a non-broken state.
- **Mic suspended (after 60s silence):** both chips drop to inactive styling; a subtle one-line hint ("tap a side to start") appears somewhere unobtrusive. Disappears on first interaction.
- **Translation failure on a bubble:** show original text in the bubble with a small "tap to retry" affordance.

### First-launch / out-of-flow screens

Shown only on first run, never again:
- **Language picker** — user picks the two languages for the pair.
- **Microphone permission request** — standard OS-level prompt, framed by a brief explanatory screen if needed.
- **Swipe onboarding** — one-time animation on the chips (e.g., finger icon pulsing horizontally across them) that disappears once the user successfully swipes. Not a permanent UI element.

## Open questions

- **Freemium tipping point:** baseline is free. If Google Translate's 500k chars/month free tier is exceeded, what's the trigger for a paid upgrade? Per-device monthly cap, optional upgrade prompt, or just absorb the cost? Defer until close to the limit.
- **Per-language STT fallback:** if `speech_to_text` quality is poor for a target language, we'll add cloud STT (likely Whisper) just for that language. Which languages need this is TBD, discovered via testing.
- **Android STT session-gap limitation (workaround applied):** Android's `SpeechRecognizer` is session-based — it ends sessions after ~1s of silence, with a ~100–500ms auto-restart gap. To make this visible rather than invisible, we commit a bubble on every platform `isFinal=true` (rather than accumulating across sessions). Users see the bubble commit, learn to pause briefly before continuing. Words spoken in the auto-restart gap can still be clipped, but the failure mode is now predictable and learnable. Full fix would require cloud streaming STT (Whisper, Google Cloud Speech) or direct `AudioRecord` capture — substantial work, deferred to post-MVP. iOS and Web don't have this issue.
- **Language-change-on-main-page (deferred):** for MVP, language change lives only in settings. If user testing later shows people change languages frequently, revisit with a long-press-chip shortcut.

## Tech stack

- **Framework:** Flutter (iOS + Android, single codebase). User has prior Flutter experience.
- **STT:** `speech_to_text` package (native iOS Speech / Android SpeechRecognizer). On-device, free, supports streaming partial results for the live draft bubble. Cloud STT (Whisper) reserved as a per-language fallback if quality is insufficient.
- **Translation:** Google Translate API. 500k chars/month free, ~100+ languages, simple REST.
- **Backend:** Cloudflare Worker proxy. Holds the Google Translate API key server-side, rate-limits per device, allows provider swaps without app updates. ~100k requests/day free tier.
- **State management:** Riverpod.
- **HTTP client:** `dio` (retries, timeouts, interceptors).
- **Permissions:** `permission_handler` (microphone only).
- **Local storage:** `shared_preferences` for chosen languages and settings. No conversation persistence — conversations are in-memory only and clear on app close.
- **Project structure:** feature-first (`lib/features/conversation/`, `lib/features/settings/`, `lib/core/`).
- **Animations:** Flutter built-ins (`AnimatedContainer`, `AnimatedSwitcher`). No third-party animation packages.
- **i18n:** English only for MVP. All user-facing strings wrapped in `intl` from day one to make later localization cheap.
- **Internet:** required for translation. On-device STT works offline; translation does not. Show offline indicator if network is unavailable.
- **Battery:** auto-suspend mic after ~60s of total silence; enter neutral state with subtle hint to tap or swipe.

## Out of scope (for now)

- Group conversations (3+ people).
- Voice playback / TTS.
- Conversation export, sharing, or cloud sync.
- Accounts, login, user profiles.
- Anything that adds a tap to a single turn.
- Custom translation tuning, glossaries, domain modes.
