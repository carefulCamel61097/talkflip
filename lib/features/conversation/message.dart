class Message {
  final int id;
  final String originalText;
  final String? translatedText;
  final bool translationFailed;
  final bool isLeft;

  const Message({
    required this.id,
    required this.originalText,
    required this.translatedText,
    required this.isLeft,
    this.translationFailed = false,
  });
}
