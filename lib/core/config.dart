class AppConfig {
  AppConfig._();

  /// Cloudflare Worker that proxies translation requests to Google Translate.
  /// The Worker holds the Google API key in its secret store; this URL is
  /// public-facing and safe to commit.
  static const String translationWorkerUrl =
      'https://talkflip-translator.talkflip.workers.dev';

  /// WebSocket endpoint on the same Worker that relays streaming microphone
  /// audio to the cloud STT provider. Derived from [translationWorkerUrl]
  /// (https -> wss). The provider key stays server-side in the Worker.
  static String get sttStreamUrl =>
      '${translationWorkerUrl.replaceFirst('https://', 'wss://')}/stt-stream';

  /// Selects the speech-to-text engine: `true` = cloud streaming (Deepgram via
  /// the Worker), `false` = native on-device.
  ///
  /// Defaults to on-device so the app keeps working without the deployed STT
  /// Worker. Flip to `true` (and hot-restart) to A/B the cloud engine on a
  /// device — it requires the Worker deployed with the `/stt-stream` route and
  /// the `DEEPGRAM_API_KEY` secret set. Will become the default once validated.
  static const bool useCloudStt = true;

  /// Shared secret the app presents to the Worker's `/stt-stream` endpoint so a
  /// stranger who finds the public URL can't burn cloud STT minutes.
  ///
  /// This is a deliberately low-value "speed bump", not a real credential: it
  /// ships inside the app and is therefore extractable, so it only raises the
  /// bar against casual abuse — the per-device and global monthly minute caps in
  /// the Worker are the real guard. Override at build time with
  /// `--dart-define=STT_APP_TOKEN=...`; the committed default keeps local/dev
  /// builds working without the flag. Rotate by changing this value and the
  /// Worker's `STT_APP_TOKEN` secret together.
  static const String sttAppToken = String.fromEnvironment(
    'STT_APP_TOKEN',
    defaultValue: '60cfba60cbc07160583a1166b96410af09233ed1497f3f06',
  );
}
