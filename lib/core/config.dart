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
  static const bool useCloudStt = false;
}
