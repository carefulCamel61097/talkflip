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
}
