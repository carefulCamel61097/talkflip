import 'package:flutter/material.dart';

import '../../core/theme.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.chatBackground,
      appBar: AppBar(
        title: const Text('About'),
        backgroundColor: AppColors.chatBackground,
        foregroundColor: AppColors.translatedText,
        elevation: 0,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ConvoGo',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'A minimalist face-to-face translator for two people, one phone.',
              style: TextStyle(fontSize: 16, color: AppColors.subtleText),
            ),
            SizedBox(height: 32),
            Text(
              'Privacy',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              "ConvoGo uses your microphone to transcribe what you say. Your "
              "speech is streamed to a cloud speech-to-text service to produce "
              "the transcript, and the transcribed text is sent to Google "
              "Translate — both via a thin proxy we operate. Audio and text are "
              "used only to do the translation and aren't stored on any server. "
              "Conversations stay on your device in memory only — they're "
              "cleared when you close the app.",
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
