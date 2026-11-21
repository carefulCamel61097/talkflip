import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_mode.dart';
import 'core/conversation_store.dart';
import 'core/theme.dart';
import 'features/conversation/conversation_page.dart';
import 'features/conversation/language_pair.dart';
import 'features/conversation/language_picker_page.dart';
import 'features/settings/read_back_setting.dart';
import 'features/text_mode/text_conversation_page.dart';

void main() {
  runApp(const ProviderScope(child: ConvoGoApp()));
}

class ConvoGoApp extends StatelessWidget {
  const ConvoGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ConvoGo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF128C7E)),
        scaffoldBackgroundColor: const Color(0xFFECE5DD),
      ),
      home: const _AppRouter(),
    );
  }
}

class _AppRouter extends ConsumerWidget {
  const _AppRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pair = ref.watch(languagePairProvider);
    // Wait for the saved mode too, so a text-mode user doesn't see voice mode
    // flash on launch. A failed mode read just falls back to voice.
    final mode = ref.watch(appModeProvider);
    // Saved conversations are read once at startup, before either mode's
    // conversation is built, so restoring them is synchronous there.
    final saved = ref.watch(savedConversationsProvider);
    final readBack = ref.watch(readBackProvider);
    if (mode.isLoading || saved.isLoading || readBack.isLoading) {
      return const _SplashScreen();
    }
    return pair.when(
      loading: () => const _SplashScreen(),
      error: (_, _) => const _ErrorScreen(),
      data: (p) {
        if (p == null) return const LanguagePickerPage();
        return mode.value == AppMode.text
            ? const TextConversationPage()
            : const ConversationPage();
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.chatBackground,
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Something went wrong loading your settings. Try restarting the app.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
