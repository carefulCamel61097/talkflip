class Message {
  final String originalText;
  final String translatedText;
  final bool isLeft;

  const Message({
    required this.originalText,
    required this.translatedText,
    required this.isLeft,
  });
}
