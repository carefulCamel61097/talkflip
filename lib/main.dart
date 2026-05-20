import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'features/conversation/conversation_page.dart';
import 'features/conversation/language_pair.dart';
import 'features/conversation/language_picker_page.dart';

void main() {
  runApp(const ProviderScope(child: TalkFlipApp()));
}

class TalkFlipApp extends StatelessWidget {
  const TalkFlipApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TalkFlip',
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
    return pair.when(
      loading: () => const _SplashScreen(),
      error: (_, _) => const _ErrorScreen(),
      data: (p) =>
          p == null ? const LanguagePickerPage() : const ConversationPage(),
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
