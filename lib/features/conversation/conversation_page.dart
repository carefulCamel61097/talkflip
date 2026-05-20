import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../settings/settings_page.dart';
import 'active_side.dart';
import 'conversation_state.dart';
import 'draft_bubble.dart';
import 'language_pair.dart';
import 'message_bubble.dart';

class ConversationPage extends ConsumerStatefulWidget {
  const ConversationPage({super.key});

  @override
  ConsumerState<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends ConsumerState<ConversationPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final convo = ref.watch(conversationProvider);
    final notifier = ref.read(conversationProvider.notifier);

    ref.listen(conversationProvider, (previous, next) {
      final prevCount = previous?.messages.length ?? 0;
      final prevDraft = previous?.draftText ?? '';
      if (next.messages.length > prevCount || next.draftText != prevDraft) {
        _scrollToBottom();
      }
    });

    final pair = ref.watch(languagePairProvider).value;
    final leftCode = pair?.left.chipLabel ?? 'EN';
    final rightCode = pair?.right.chipLabel ?? 'ES';

    final showDraft = convo.activeSide != ActiveSide.neutral;
    final draftIsLeft = convo.activeSide == ActiveSide.left;

    return Scaffold(
      backgroundColor: AppColors.chatBackground,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            // Lower than typical mobile flick velocities to also catch
            // slower mouse drags in Chrome during dev.
            const swipeVelocityThreshold = 200.0;
            final velocity = details.primaryVelocity ?? 0.0;
            // Carousel convention: swipe pushes the current side away,
            // revealing the opposite side. Swipe right → activate left;
            // swipe left → activate right.
            if (velocity > swipeVelocityThreshold) {
              notifier.activate(ActiveSide.left);
            } else if (velocity < -swipeVelocityThreshold) {
              notifier.activate(ActiveSide.right);
            }
          },
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
                  controller: _scrollController,
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
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: IconButton(
        icon: const Icon(
          Icons.settings_outlined,
          size: 22,
          color: AppColors.settingsCog,
        ),
        tooltip: 'Settings',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsPage()),
          );
        },
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
