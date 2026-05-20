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
              "ConvoGo uses your microphone to transcribe what you say. "
              "Transcribed text is sent to Google Translate, via a thin proxy "
              "we operate, to be translated into the other language. "
              "Conversations stay on your device in memory only — they're not "
              "stored on any server and are cleared when you close the app.",
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
