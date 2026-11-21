import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../settings/read_back_setting.dart';
import 'message.dart';

/// Dual-text bubble: original small and dimmed, translation large and bold.
///
/// Gestures (all optional, so each mode wires only what it needs):
/// - [onRetry]: whole-bubble tap on a failed translation.
/// - [onCopyOriginal] / [onCopyTranslation]: tap on that *part* of the bubble
///   (text mode). When null, taps pass through to the parent — in voice mode a
///   tap on the chat area switches sides.
/// - [onLongPress]: the copy/delete menu (both modes).
class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isActiveSide;
  final VoidCallback? onRetry;
  final VoidCallback? onCopyOriginal;
  final VoidCallback? onCopyTranslation;
  final VoidCallback? onLongPress;

  /// Text mode: show the "Reads back as: …" line when the message has one.
  final bool showReadBack;

  const MessageBubble({
    super.key,
    required this.message,
    this.isActiveSide = false,
    this.onRetry,
    this.onCopyOriginal,
    this.onCopyTranslation,
    this.onLongPress,
    this.showReadBack = false,
  });

  @override
  Widget build(BuildContext context) {
    final isLeft = message.isLeft;
    final alignment = isLeft ? Alignment.centerLeft : Alignment.centerRight;
    final bubbleColor = isLeft ? AppColors.leftBubble : AppColors.rightBubble;
    final textAlign = isLeft ? TextAlign.left : TextAlign.right;
    final maxWidth = MediaQuery.of(context).size.width * 0.75;
    final failed = message.translationFailed;
    final readBack = showReadBack &&
        message.readBack != null &&
        readBackDiffers(message.originalText, message.readBack!);

    return Align(
      alignment: alignment,
      child: GestureDetector(
        onTap: failed ? onRetry : null,
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
          // IntrinsicWidth + stretch: both parts span the full bubble width, so
          // the whole bubble is tappable and splits cleanly into an upper
          // (original) and lower (translation) target.
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _part(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
                  onTap: failed ? null : onCopyOriginal,
                  child: Text(
                    message.originalText,
                    style: AppTextStyles.original,
                    textAlign: textAlign,
                  ),
                ),
                _part(
                  padding: EdgeInsets.fromLTRB(14, 2, 14, readBack ? 4 : 10),
                  onTap: message.translatedText == null ? null : onCopyTranslation,
                  child: Align(
                    alignment: alignment,
                    child: _translationSlot(textAlign),
                  ),
                ),
                if (readBack)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    padding: const EdgeInsets.only(top: 4, bottom: 9),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0x1F000000)),
                      ),
                    ),
                    child: Text(
                      'Reads back as: ${message.readBack}',
                      textAlign: textAlign,
                      style: AppTextStyles.original.copyWith(
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _part({
    required EdgeInsets padding,
    required VoidCallback? onTap,
    required Widget child,
  }) {
    final padded = Padding(padding: padding, child: child);
    if (onTap == null) return padded;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: padded,
    );
  }

  Widget _translationSlot(TextAlign textAlign) {
    if (message.translatedText != null) {
      return Text(
        message.translatedText!,
        style: AppTextStyles.translated,
        textAlign: textAlign,
      );
    }
    if (message.limitReached) {
      // Non-retryable: the monthly free-tier cap was hit. No retry affordance
      // because retrying won't help until the month resets.
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.hourglass_empty, size: 16, color: AppColors.subtleText),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'monthly translation limit reached',
              style: AppTextStyles.translated.copyWith(
                fontSize: 14,
                color: AppColors.subtleText,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      );
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
