import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isActiveSide;
  final VoidCallback? onRetry;

  const MessageBubble({
    super.key,
    required this.message,
    this.isActiveSide = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final alignment = message.isLeft ? Alignment.centerLeft : Alignment.centerRight;
    final bubbleColor = message.isLeft ? AppColors.leftBubble : AppColors.rightBubble;
    final crossAxis = message.isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end;
    final maxWidth = MediaQuery.of(context).size.width * 0.75;

    return Align(
      alignment: alignment,
      child: GestureDetector(
        onTap: message.translationFailed ? onRetry : null,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: maxWidth),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActiveSide
                  ? AppColors.accent.withValues(alpha: 0.7)
                  : Colors.transparent,
              width: 2.0,
            ),
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
              _translationSlot(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _translationSlot() {
    if (message.translatedText != null) {
      return Text(message.translatedText!, style: AppTextStyles.translated);
    }
    if (message.translationFailed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.refresh, size: 16, color: AppColors.accent),
          const SizedBox(width: 4),
          Text(
            'tap to retry',
            style: AppTextStyles.translated.copyWith(
              fontSize: 14,
              color: AppColors.accent,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }
    return Text('…', style: AppTextStyles.translated);
  }
}
