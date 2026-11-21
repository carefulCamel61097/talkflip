class Message {
  final int id;
  final String originalText;
  final String? translatedText;
  final bool translationFailed;

  /// Translation was blocked by the free-tier monthly cap. Distinct from
  /// [translationFailed] because it is not retryable until the month resets.
  final bool limitReached;

  /// Screen side. Left = the other person ("theirs"), right = you ("mine").
  final bool isLeft;

  /// Text mode only: [translatedText] translated back into the original
  /// language, so you can check what you're about to send ("reads back as…").
  final String? readBack;

  const Message({
    required this.id,
    required this.originalText,
    required this.translatedText,
    required this.isLeft,
    this.translationFailed = false,
    this.limitReached = false,
    this.readBack,
  });

  /// Same message with a new translation outcome. [translatedText] null with
  /// both flags false means "translating…" (pending). Clears any read-back,
  /// since it belonged to the previous translation.
  Message withTranslation({
    required String? translatedText,
    bool failed = false,
    bool limitReached = false,
  }) {
    return Message(
      id: id,
      originalText: originalText,
      translatedText: translatedText,
      isLeft: isLeft,
      translationFailed: failed,
      limitReached: limitReached,
    );
  }

  Message withReadBack(String readBack) {
    return Message(
      id: id,
      originalText: originalText,
      translatedText: translatedText,
      isLeft: isLeft,
      translationFailed: translationFailed,
      limitReached: limitReached,
      readBack: readBack,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'original': originalText,
        if (translatedText != null) 'translated': translatedText,
        'left': isLeft,
        if (translationFailed) 'failed': true,
        if (limitReached) 'limit': true,
        if (readBack != null) 'readBack': readBack,
      };

  /// Restores a saved message. A translation that was still in flight when
  /// the app closed comes back as failed, so it shows "tap to retry" instead
  /// of an endless "…".
  static Message fromJson(Map<String, dynamic> json) {
    final translated = json['translated'] as String?;
    final limit = json['limit'] == true;
    return Message(
      id: json['id'] as int,
      originalText: json['original'] as String,
      translatedText: translated,
      isLeft: json['left'] as bool,
      translationFailed:
          json['failed'] == true || (translated == null && !limit),
      limitReached: limit,
      readBack: json['readBack'] as String?,
    );
  }
}
