# ConvoGo — Privacy Policy

**Effective date:** 21 November 2026

ConvoGo is a translation app for talking face to face on one shared phone (voice mode) and for chatting in other messaging apps (text mode). This page explains what data the app handles and how.

**In short:** ConvoGo has no accounts, no analytics, and no tracking. Your conversations are not stored on any server — the app keeps your current conversation on your phone until you clear it.

## What ConvoGo collects

- **Microphone audio** is captured only when you actively start a turn (by tapping a language chip or swiping). The audio is streamed over an encrypted connection to a cloud speech-to-text provider (see "Third parties" below) to produce a text transcript in real time. The audio is used only for that transcription; ConvoGo does not record or store it. If the cloud service is unreachable, the app falls back to your device's built-in speech recognition (Apple Speech on iOS, Google's speech service on Android).
- **Text** (transcribed speech in voice mode, or the message you type or paste in text mode) is sent over the network to ConvoGo's translation server (see "Third parties" below) so it can be translated into the other language.
- **Clipboard (text mode):** read only when you tap *Paste*; written when you send a message (the translation) or tap a bubble to copy it. Never read in the background.
- **Language preferences, settings and your current conversations** are stored locally on your device. They never leave your device.
- **An anonymous install ID** (random, created by the app on first use) is sent with speech requests so the server can count monthly audio minutes per installation for a fair-use limit. It isn't linked to your name, account, phone number or advertising ID, and the count contains no audio or text.

## What ConvoGo does NOT collect

- No accounts, sign-ins, or personal identifiers
- No analytics, tracking, or behavioural data
- No advertising or ad-related identifiers
- No conversation history on our servers — conversations stay on your phone and are never synced
- No location, contacts, photos, or other device data

## Third parties

For speech-to-text and translation to work, your audio and the resulting text are sent to:

1. **Cloudflare Workers** — ConvoGo's proxy server runs on Cloudflare's infrastructure and routes both the audio stream and the translation requests. Cloudflare may log standard network metadata (such as IP address and request timestamp) as part of routine network operations. See [Cloudflare's privacy policy](https://www.cloudflare.com/privacypolicy/).
2. **Deepgram** — cloud speech-to-text. The microphone audio is streamed (via the Cloudflare proxy) to Deepgram, which transcribes it to text in real time. The audio is processed to produce the transcript and is not retained by ConvoGo. See [Deepgram's privacy policy](https://deepgram.com/privacy).
3. **Google Cloud Translation API** — the actual translation is performed by Google's Cloud Translation service, which receives the transcribed text and returns the translated text. See [Google's privacy policy](https://policies.google.com/privacy).

If the cloud speech service is unreachable, ConvoGo falls back to your device's built-in speech recognition (Apple's Speech framework on iOS, Google's SpeechRecognizer on Android). In that case the audio is handled by the platform under Apple's or Google's own privacy policy, which ConvoGo does not control.

## Permissions

ConvoGo requests **microphone access**. This is the only permission required. Without it, the app cannot transcribe speech. You can grant or revoke this permission at any time from your device's settings.

## Data retention

- **Transcribed text** sent to the translation server is processed and returned. ConvoGo does not store it beyond what is required to fulfil the request.
- **Language preferences** stored on your device remain there until you uninstall the app or clear its data.
- **Conversations** are stored only on your device, until you tap *Clear* or uninstall the app.

## Security

Network traffic between ConvoGo and the translation server uses HTTPS. ConvoGo does not transmit, store, or share data beyond what is required to translate your speech.

## Children's privacy

ConvoGo is not directed at children under 13 and ConvoGo's developers do not knowingly collect data from them.

## Changes to this policy

If ConvoGo changes how it handles data, this page will be updated and the effective date at the top will change. Material changes will also be reflected in a new app release.

## Contact

Questions about this policy or ConvoGo's data handling: epema.thabiso+convogo@gmail.com
