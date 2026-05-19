# TalkFlip *(working title)*

A minimalist face-to-face translator for two people, one phone.

> **Status:** in development — see [ROADMAP.md](ROADMAP.md) for the build plan.

## What it does

Two people standing face to face who don't share a language. One holds a phone, points it at the other, and they have a conversation. Each person speaks; the app transcribes their words, translates them, and shows both texts on screen as a dual-language chat. No buttons to press, no audio playback, no friction.

## Core principles

The whole product is shaped by a handful of principles documented in [CLAUDE.md](CLAUDE.md):

- **Two people, one phone, one moment.** Optimised for the specific situation of two humans face-to-face.
- **Minimal interactions per turn.** No "record" or "stop" buttons — switching speakers is the only signal.
- **Read, don't listen.** No text-to-speech. Reading is faster, quieter, and works in noisy places.
- **One-handed operation.** The phone-holder controls both sides with their thumb.

## Tech stack

Flutter (iOS + Android) · Riverpod · `speech_to_text` (on-device STT) · Google Translate (via Cloudflare Worker proxy) · `dio` · `shared_preferences`

See [CLAUDE.md](CLAUDE.md) for the full design and engineering decisions.
