class AppConfig {
  AppConfig._();

  /// Cloudflare Worker that proxies translation requests to Google Translate.
  /// The Worker holds the Google API key in its secret store; this URL is
  /// public-facing and safe to commit.
  static const String translationWorkerUrl =
      'https://talkflip-translator.talkflip.workers.dev';
}
