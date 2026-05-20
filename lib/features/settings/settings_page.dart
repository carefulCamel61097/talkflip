import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../conversation/conversation_state.dart';
import '../conversation/language_pair.dart';
import '../conversation/language_picker_page.dart';
import 'about_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pair = ref.watch(languagePairProvider).value;

    return Scaffold(
      backgroundColor: AppColors.chatBackground,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.chatBackground,
        foregroundColor: AppColors.translatedText,
        elevation: 0,
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.translate, color: AppColors.accent),
            title: const Text('Change languages'),
            subtitle: pair == null
                ? null
                : Text('${pair.left.displayName} & ${pair.right.displayName}'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LanguagePickerPage(initialPair: pair),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: AppColors.accent),
            title: const Text('Clear conversation'),
            onTap: () => _clearConversation(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline, color: AppColors.accent),
            title: const Text('About'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _clearConversation(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear conversation?'),
        content: const Text(
          "All messages from this session will be removed. This can't be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      ref.read(conversationProvider.notifier).clearMessages();
      Navigator.pop(context);
    }
  }
}
