import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/conversation/conversation_page.dart';

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
      home: const ConversationPage(),
    );
  }
}
