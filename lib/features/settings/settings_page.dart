import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../conversation/language_pair.dart';
import '../conversation/connectivity_provider.dart';
import '../conversation/language_picker_page.dart';
import '../conversation/stt_engine.dart';
import 'about_page.dart';
import 'read_back_setting.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pair = ref.watch(languagePairProvider).value;
    final isOnline = ref.watch(connectivityProvider).value ?? true;
    // Same condition as the amber dot next to the cog, explained in words.
    final onFallbackStt =
        isOnline && ref.watch(sttModeProvider) == SttMode.fallback;
    final readBack =
        ref.watch(readBackProvider).value ?? ReadBackNotifier.defaultValue;

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
          if (onFallbackStt)
            const ListTile(
              leading: Padding(
                padding: EdgeInsets.all(7),
                child: SizedBox(
                  width: 10,
                  height: 10,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFD9A05B),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              title: Text('Using basic speech recognition'),
              subtitle: Text(
                "Cloud speech recognition isn't reachable right now, so your "
                "phone's built-in recognition is used. It may be less accurate, "
                "and some languages may not work. ConvoGo switches back "
                'automatically.',
              ),
            ),
          if (!isOnline)
            const ListTile(
              leading: Padding(
                padding: EdgeInsets.all(7),
                child: SizedBox(
                  width: 10,
                  height: 10,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFB0B0B0),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              title: Text("You're offline"),
              subtitle: Text('Translation needs an internet connection.'),
            ),
          ListTile(
            leading: const Icon(Icons.translate, color: AppColors.accent),
            title: const Text('Change languages'),
            subtitle: pair == null
                ? null
                : Text('${pair.mine.displayName} & ${pair.theirs.displayName}'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LanguagePickerPage(initialPair: pair),
                ),
              );
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.fact_check_outlined, color: AppColors.accent),
            title: const Text('Read-back check'),
            subtitle: Text(
              'Text mode: under your messages, show what the translation says '
              'in ${pair?.mine.displayName ?? 'your language'}, so you can '
              'check it before sending.',
            ),
            value: readBack,
            activeThumbColor: AppColors.accent,
            onChanged: (v) => ref.read(readBackProvider.notifier).set(v),
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
}
