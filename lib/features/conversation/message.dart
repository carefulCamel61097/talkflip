class Message {
  final int id;
  final String originalText;
  final String? translatedText;
  final bool translationFailed;

  /// Translation was blocked by the free-tier monthly cap. Distinct from
  /// [translationFailed] because it is not retryable until the month resets.
  final bool limitReached;
  final bool isLeft;

  const Message({
    required this.id,
    required this.originalText,
    required this.translatedText,
    required this.isLeft,
    this.translationFailed = false,
    this.limitReached = false,
  });
}
