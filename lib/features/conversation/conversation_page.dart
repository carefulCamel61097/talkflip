import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import 'active_side.dart';
import 'conversation_state.dart';
import 'draft_bubble.dart';
import 'message_bubble.dart';

class ConversationPage extends ConsumerWidget {
  const ConversationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convo = ref.watch(conversationProvider);
    final notifier = ref.read(conversationProvider.notifier);

    const leftCode = 'EN';
    const rightCode = 'ES';

    final showDraft = convo.activeSide != ActiveSide.neutral;
    final draftIsLeft = convo.activeSide == ActiveSide.left;

    return Scaffold(
      backgroundColor: AppColors.chatBackground,
      body: SafeArea(
        child: Column(
          children: [
            const _TopBar(),
            _LanguageChipsRow(
              leftCode: leftCode,
              rightCode: rightCode,
              activeSide: convo.activeSide,
              onLeftTap: () => notifier.activate(ActiveSide.left),
              onRightTap: () => notifier.activate(ActiveSide.right),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: convo.messages.length + (showDraft ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < convo.messages.length) {
                    final message = convo.messages[index];
                    final isActiveSide =
                        (message.isLeft && convo.activeSide == ActiveSide.left) ||
                            (!message.isLeft && convo.activeSide == ActiveSide.right);
                    return MessageBubble(
                      message: message,
                      isActiveSide: isActiveSide,
                      onRetry: () => notifier.retryTranslation(message.id),
                    );
                  }
                  return DraftBubble(
                    text: convo.draftText,
                    isLeft: draftIsLeft,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Icon(
        Icons.settings_outlined,
        size: 22,
        color: AppColors.settingsCog,
      ),
    );
  }
}

class _LanguageChipsRow extends StatelessWidget {
  final String leftCode;
  final String rightCode;
  final ActiveSide activeSide;
  final VoidCallback onLeftTap;
  final VoidCallback onRightTap;

  const _LanguageChipsRow({
    required this.leftCode,
    required this.rightCode,
    required this.activeSide,
    required this.onLeftTap,
    required this.onRightTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _LanguageChip(
            code: leftCode,
            isActive: activeSide == ActiveSide.left,
            onTap: onLeftTap,
          ),
          _LanguageChip(
            code: rightCode,
            isActive: activeSide == ActiveSide.right,
            onTap: onRightTap,
          ),
        ],
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  final String code;
  final bool isActive;
  final VoidCallback onTap;

  const _LanguageChip({
    required this.code,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.activeChipFill : AppColors.inactiveChipFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accent, width: 1.5),
        ),
        child: Text(
          code,
          style: AppTextStyles.languageChip.copyWith(
            color: isActive ? AppColors.activeChipText : AppColors.inactiveChipText,
          ),
        ),
      ),
    );
  }
}
