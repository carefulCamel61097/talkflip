import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isActiveSide;

  const MessageBubble({
    super.key,
    required this.message,
    this.isActiveSide = false,
  });

  @override
  Widget build(BuildContext context) {
    final alignment = message.isLeft ? Alignment.centerLeft : Alignment.centerRight;
    final bubbleColor = message.isLeft ? AppColors.leftBubble : AppColors.rightBubble;
    final crossAxis = message.isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end;
    final maxWidth = MediaQuery.of(context).size.width * 0.75;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: maxWidth),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(12),
          border: isActiveSide
              ? Border.all(color: AppColors.accent.withValues(alpha: 0.7), width: 2.0)
              : null,
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: crossAxis,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message.originalText, style: AppTextStyles.original),
            const SizedBox(height: 4),
            Text(message.translatedText, style: AppTextStyles.translated),
          ],
        ),
      ),
    );
  }
}
