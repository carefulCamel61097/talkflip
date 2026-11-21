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
              'A minimalist translator for face-to-face conversations on one phone, and for chatting in other apps.',
              style: TextStyle(fontSize: 16, color: AppColors.subtleText),
            ),
            SizedBox(height: 32),
            Text(
              'Privacy',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              "In voice mode, ConvoGo uses your microphone to transcribe what "
              "you say: your speech is streamed to a cloud speech-to-text "
              "service. The text (transcribed, typed or pasted) is sent to "
              "Google Translate. Both go through a thin proxy we operate, and "
              "audio and text are used only to do the translation — they "
              "aren't stored on any server. In text mode, the clipboard is "
              "read only when you tap Paste. Your conversations are saved on "
              "this phone only, until you tap Clear.",
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
