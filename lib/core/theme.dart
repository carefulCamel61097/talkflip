import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color chatBackground = Color(0xFFECE5DD);
  static const Color topBarBackground = Color(0xFFEDEDED);

  static const Color leftBubble = Color(0xFFDCF8C6);
  static const Color rightBubble = Color(0xFFFFFFFF);

  static const Color originalText = Color(0xFF6B7280);
  static const Color translatedText = Color(0xFF111827);
  static const Color subtleText = Color(0xFF6B7280);

  static const Color accent = Color(0xFF128C7E);
  static const Color accentDark = Color(0xFF075E54);
  static const Color activeChipFill = Color(0xFF128C7E);
  static const Color activeChipText = Color(0xFFFFFFFF);
  static const Color inactiveChipFill = Color(0xFFFFFFFF);
  static const Color inactiveChipText = Color(0xFF128C7E);

  static const Color settingsCog = Color(0xFF6B7280);
}

class AppTextStyles {
  AppTextStyles._();

  static const TextStyle original = TextStyle(
    fontSize: 13,
    color: AppColors.originalText,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );

  static const TextStyle translated = TextStyle(
    fontSize: 18,
    color: AppColors.translatedText,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const TextStyle draftOriginal = TextStyle(
    fontSize: 16,
    color: AppColors.subtleText,
    fontWeight: FontWeight.w500,
    fontStyle: FontStyle.italic,
    height: 1.3,
  );

  static const TextStyle languageChip = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
  );
}
