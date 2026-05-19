import 'package:flutter/material.dart';

import '../../core/theme.dart';

class DraftBubble extends StatelessWidget {
  final String text;
  final bool isLeft;

  const DraftBubble({
    super.key,
    required this.text,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    final alignment = isLeft ? Alignment.centerLeft : Alignment.centerRight;
    final baseColor = isLeft ? AppColors.leftBubble : AppColors.rightBubble;
    final maxWidth = MediaQuery.of(context).size.width * 0.75;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: maxWidth),
        decoration: BoxDecoration(
          color: baseColor.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.55),
            width: 1.2,
          ),
        ),
        child: Text(text, style: AppTextStyles.draftOriginal),
      ),
    );
  }
}
