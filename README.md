# ConvoGo

A minimalist translator for face-to-face conversations on one phone, and for chatting in other apps.

> **Status:** live on Google Play and the App Store (1.1.x); **1.2.0** (text mode) submitted to both stores on 2026-11-21. See [ROADMAP.md](ROADMAP.md).

## What it does

Two people standing face to face who don't share a language. One holds a phone, points it at the other, and they have a conversation. Each person speaks; the app transcribes their words, translates them, and shows both texts on screen as a dual-language chat. No buttons to press, no audio playback, no friction.

**Text mode** covers the other common case: someone messages you in another language on WhatsApp, LINE or similar. Paste their message to read it in your language, type your reply, and the translation is copied to your clipboard, ready to paste back.

## Core principles

The whole product is shaped by a handful of principles documented in [CLAUDE.md](CLAUDE.md):

- **Two people, one phone, one moment.** Voice mode is optimised for two humans face-to-face; text mode is the one deliberate exception (chatting in another app).
- **Minimal interactions per turn.** No "record" or "stop" buttons — switching speakers is the only signal.
- **Read, don't listen.** No text-to-speech. Reading is faster, quieter, and works in noisy places.
- **One-handed operation.** The phone-holder controls both sides with their thumb.

## Tech stack

Flutter (iOS + Android) · Riverpod · cloud STT via Deepgram (streamed through a Cloudflare Worker), with `speech_to_text` on-device as fallback · Google Translate (via the same Worker) · `record` · `dio` · `shared_preferences`

See [CLAUDE.md](CLAUDE.md) for the full design and engineering decisions.

## A note on naming

The app was originally scaffolded under the working title **TalkFlip** before being renamed to ConvoGo. The user-facing brand changed; the internal identifiers did not. So you'll still see `talkflip` in:

- The GitHub repo name (`carefulCamel61097/talkflip`)
- The bundle ID (`com.carefulcamel61097.talkflip`)
- The Dart package name (`talkflip`, used in all `import 'package:talkflip/...'` lines)
- The Cloudflare Worker URL (`talkflip-translator.talkflip.workers.dev`)

These were kept stable because changing them would mean breaking deployed infrastructure, invalidating package imports across the codebase, and reissuing the bundle ID before any app store submission. They're internal identifiers, not user-facing, so the inconsistency is contained.
