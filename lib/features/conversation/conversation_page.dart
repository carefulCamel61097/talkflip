import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import 'draft_bubble.dart';
import 'message.dart';
import 'message_bubble.dart';

class ConversationPage extends ConsumerWidget {
  const ConversationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const activeIsLeft = true;
    const leftCode = 'EN';
    const rightCode = 'ES';

    const mockMessages = <Message>[
      Message(
        originalText: 'Hello, how are you?',
        translatedText: 'Hola, ¿cómo estás?',
        isLeft: true,
      ),
      Message(
        originalText: 'Muy bien, gracias. ¿Y tú?',
        translatedText: 'Very well, thank you. And you?',
        isLeft: false,
      ),
      Message(
        originalText: 'I am good. Where are you from?',
        translatedText: 'Estoy bien. ¿De dónde eres?',
        isLeft: true,
      ),
      Message(
        originalText: 'Soy de Buenos Aires. ¿Y tú?',
        translatedText: 'I am from Buenos Aires. And you?',
        isLeft: false,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.chatBackground,
      body: SafeArea(
        child: Column(
          children: [
            const _TopBar(),
            const _LanguageChipsRow(
              leftCode: leftCode,
              rightCode: rightCode,
              activeIsLeft: activeIsLeft,
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: mockMessages.length + 1,
                itemBuilder: (context, index) {
                  if (index < mockMessages.length) {
                    final message = mockMessages[index];
                    return MessageBubble(
                      message: message,
                      isActiveSide: message.isLeft == activeIsLeft,
                    );
                  }
                  return const DraftBubble(
                    text: 'so where exactly in Argentina...',
                    isLeft: activeIsLeft,
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
  final bool activeIsLeft;

  const _LanguageChipsRow({
    required this.leftCode,
    required this.rightCode,
    required this.activeIsLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _LanguageChip(code: leftCode, isActive: activeIsLeft),
          _LanguageChip(code: rightCode, isActive: !activeIsLeft),
        ],
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  final String code;
  final bool isActive;

  const _LanguageChip({required this.code, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}
