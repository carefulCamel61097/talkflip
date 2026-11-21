# ConvoGo

A hyper-minimalist, two-person, face-to-face translation app. One phone, two languages, zero friction.

## Core principles

These guide every product and engineering decision. When in doubt, refer back here.

1. **Two people, one phone, one moment.** Voice mode is optimized for two humans standing face-to-face, passing a single phone back and forth. The one deliberate exception is **text mode** (see below): one person chatting in another app (WhatsApp, LINE, …) with someone who writes another language. Features that serve neither situation are out of scope.
2. **Minimal interactions per turn.** A speaker should start a turn, deliver it, and end it without pressing any explicit "record" or "stop" button. Handing the phone over is the only signal we need.
3. **Read, don't listen.** Text is faster than synthesized speech, works in noisy environments, and avoids robot voices. No TTS.
4. **Discoverability AND elegance.** Gestures are powerful but invisible. Every primary action must also have a visible, tappable affordance. Gestures are a faster shortcut, never the only path.
5. **Always show both sides.** Both speakers' transcripts are visible at all times. Indicate the active speaker by highlighting their bubbles, never by hiding or dimming the other side.
6. **Smooth and fast > feature-rich.** Any feature that adds latency, taps, or visual clutter must justify itself against these principles.
7. **One-handed operation.** The typical user is a traveler holding the phone in one hand, pointing it at the other person. Both sides must be activatable with a single thumb. Physical hand-off is NOT the primary mode of switching — pointing-and-swiping is.

## Locked design decisions

### Layout

**Single main page, two modes.** The app has one in-conversation screen with two modes, **voice** and **text**, switched by a small toggle in the top bar (last-used mode is remembered). Settings and onboarding live elsewhere.

**Sides: them on the left, you on the right** (WhatsApp convention), in both modes. "Your language" from the picker is always the right side, with the green bubbles; the other person's is the left, in white. Small THEM / YOU labels sit under the chips.

Anatomy of the main page, top to bottom:
1. **Top bar:** voice/text toggle on the left, small low-contrast settings cog centered, **"Clear" pill** on the right (same size as the toggle, so the bar stays visually symmetric) (clears with an "Undo" snackbar, no confirmation dialog). Connectivity indicator (see below) sits next to the cog when relevant.
2. **Language chips row:** two language-code chips (EN, ES, etc.), one on the left, one on the right, each above their own side of the chat area. In voice mode, chips are the primary tappable affordance to activate their side; in text mode they are labels only.
3. **Chat area:** chronological, WhatsApp-style. Left-side language's bubbles align left; right-side language's bubbles align right. Vertical scrolling reviews history.
4. **Active speaker's draft bubble:** rendered inside the chat area on the active side, dashed/faded, streaming live transcription as the speaker talks. On commit (silence threshold OR side switch), the draft graduates into a committed dual-text bubble.

**Dual-text bubble:** original transcribed text in small, dimmed font (so the speaker can verify accuracy); translated text directly below in large, bold font (for the listener).

**No fixed bottom strip (voice mode).** The draft lives inside the chat area, not in a dedicated bottom input zone (rejected because it breaks "both sides always visible" symmetry and pulls the speaker's eye away from their own chat side). Text mode is the exception: it needs a keyboard, so it has a bottom input bar.

**Bubble interactions (both modes).** Long-press a bubble → bottom-sheet menu: copy translation, copy original, delete bubble (delete shows "Undo"). Failed-translation bubbles: tap retries. In voice mode a plain tap on a bubble passes through to the chat area (switches sides); in text mode a tap copies exactly the part tapped — the original or the translation.

### Text mode
For chatting in another app with someone who writes another language. Same language pair, same dual-text bubbles, both sides always visible.
- **Their side (left): a "Paste" button, no text box.** One tap reads the clipboard, adds their bubble, translates it. You never type their language.
- **Your side (right): a text field + send.** On send, the translation is **copied to the clipboard automatically** ("Thai copied" snackbar), ready to paste into the chat app. The Paste button hides while you're typing.
- No microphone in text mode; switching to text mode turns the mic off.
- **Read-back line (Settings switch, default on):** under your message, what the translation says when translated back into your language. Hidden when it matches what you typed (ignoring case/punctuation), so it only appears when it can tell you something.

**Both sides always visible.** Even when one side is active, the inactive side's bubbles remain fully readable. Active state is shown by highlight on the active side, never by dimming the inactive side.

### Speaker switching
- **No "end recording" button.** Switching to the other speaker is the implicit commit.
- **Primary affordances (two, both discoverable):**
  - Tap a language chip at the top. The most explicit affordance — picks a specific side. Tapping the *already-active* chip turns that side off (back to neutral), acting as a deliberate mic-off toggle. The in-flight draft commits to its side first, same as a side-switch.
  - Tap anywhere in the chat area. Toggles the active side (left ↔ right), or activates the user's side from neutral. The most universally discoverable interaction — users naturally try tapping the chat. Failed-translation bubbles still win the tap for retry; successful bubbles pass through.
- **Secondary (shortcut):** horizontal swipe (carousel direction) does the same thing. Faster once learned, but never the only way.
- **Active-side indication (two unified cues):**
  - A 12px accent-coloured dot above the active language chip — same colour as the bubble border highlight. Familiar "online" indicator pattern; immediately glanceable.
  - A 2px accent-coloured border around the active speaker's bubbles. Border is always rendered at 2px (only the colour toggles, transparent when inactive) so activation never shifts layout.
  - Do NOT dim the inactive side — both stay fully readable.
- **Optional accent:** subtle background color shift on the active side. Both-side text contrast must remain unaffected.

### Microphone behavior
- **Continuous listening on the active side.** Mic stays open until the other side is activated, or until a longer silence suspends it (see below).
- **Intra-turn silence threshold.** A bubble commits on the first of: the cloud engine's end-of-speech signals (Deepgram `speech_final` ~300ms, or `UtteranceEnd` after a ~1s word gap) or our **3s client-side ceiling**, so it can never hang. On the on-device fallback, the platform `isFinal=true` (Android ~1s; iOS rarely) plays the role of the end-of-speech signal. Not used to switch speakers; switching is always explicit.
- **Neutral state.** Neither side is active. Reached on app open before first interaction, after a longer total silence (e.g., 30–60s, battery-saving), or by deliberately tapping the active language chip to turn the mic off.
- **Activating from neutral.** Tapping a language chip OR swiping horizontally must activate the corresponding side. Swipe must work in neutral state, not only when switching between two active states.
- **Live draft bubble.** Words stream in real-time in a faint bubble as the speaker talks. On commit (silence threshold OR side switch), the draft is finalized and translated.

### Language identifiers
- **Language codes (EN, ES, FR, …) as tappable chips.** Flags rejected for now — politically and linguistically lossy (🇺🇸 ignores UK/AU English, 🇪🇸 ignores Latin American Spanish, 🇨🇳 vs 🇹🇼 is a minefield). Revisit if users push back.

### Gestures
- **Horizontal swipe:** switch speakers OR activate a side from neutral state. **Direction convention: carousel/page-swipe model** — swipe pushes the current side off-screen and reveals the opposite side (swipe right → activate left; swipe left → activate right). Matches Instagram stories, Tinder, iOS Photos, etc. Must be reachable by a single thumb (works from the lower half of the screen at minimum).
- **Vertical swipe:** scroll conversation history.
- **Long-press a bubble:** copy / delete menu (see Bubble interactions).
- No other gestures.

### Persistence
- **Persistent language memory.** The two chosen languages persist across sessions. Reopening drops users straight into the conversation screen in under a second.
- **Conversations are kept on the phone (since 1.2.0).** One conversation per mode survives app restarts until the user clears it with the top-bar clear button. Stored locally only, never synced. (Reverses the earlier in-memory-only rule: text chats span hours or days, and losing a voice conversation to an accidental close was annoying too.)

### Settings page

Settings is reachable via the cog in the top bar. Contents:
- **Change the two languages.** This is the primary reason to enter settings.
- **Read-back check on/off** (text mode).
- When the amber/grey status dot is showing, a line at the top explains it.
- **About / privacy policy.** Required for app stores.

(Clear conversation moved to the top bar of the main screen.)

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

- **Freemium tipping point:** baseline is free. If Google Translate's 500k chars/month free tier (or the speech-minute caps) gets tight, what triggers a paid upgrade? See ROADMAP "Monetisation". Note: charging money requires switching the App Store's EU trader declaration to "trader" (public contact details) and signing the Paid Apps agreement.
- **STT quality per language (largely resolved):** cloud STT (Deepgram) is now the default for every language, with the on-device recognizer as a fallback. Still to watch: languages where Deepgram itself is weak (Spanish was patchy in one noisy Simulator test, inconclusive), and the first word after a side switch occasionally being misheard (accepted).
- **Android STT session-gap limitation (fallback only):** applies only when the app falls back to Android's on-device `SpeechRecognizer`, which ends sessions after ~1s of silence with a short auto-restart gap. There we commit a bubble on every platform `isFinal=true`, so the failure is visible and learnable. The default cloud engine streams continuously and doesn't have this gap.
- **Language-change-on-main-page (deferred):** for MVP, language change lives only in settings. If user testing later shows people change languages frequently, revisit with a long-press-chip shortcut.

## Tech stack

- **Framework:** Flutter (iOS + Android, single codebase). User has prior Flutter experience.
- **STT:** cloud streaming via **Deepgram**, relayed through the Cloudflare Worker (`/stt-stream` WebSocket), is the default since 1.1.1 — raw mic audio from the `record` package. `ResilientSttEngine` falls back to the on-device `speech_to_text` recognizer when the cloud is unreachable or over its cap (amber dot). See ROADMAP "Language-specific STT" and HANDOFF.md. Some notes below about Android `isFinal` timing describe the on-device fallback.
- **Translation:** Google Translate API. 500k chars/month free, ~100+ languages, simple REST.
- **Backend:** Cloudflare Worker proxy. Holds the Google Translate API key server-side, rate-limits per device, allows provider swaps without app updates. ~100k requests/day free tier.
- **State management:** Riverpod.
- **HTTP client:** `dio` (retries, timeouts, interceptors).
- **Permissions:** `permission_handler` (microphone only).
- **Local storage:** `shared_preferences` for chosen languages, settings and (from M11) the saved conversations. Note: the `language_pair_left` key holds *your* language, which is displayed on the **right** — the key name predates the you-on-the-right switch and was kept to avoid a migration.
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
