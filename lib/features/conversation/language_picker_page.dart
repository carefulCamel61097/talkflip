import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supported_languages.dart';
import '../../core/theme.dart';
import 'language_pair.dart';

class LanguagePickerPage extends ConsumerStatefulWidget {
  const LanguagePickerPage({super.key});

  @override
  ConsumerState<LanguagePickerPage> createState() => _LanguagePickerPageState();
}

class _LanguagePickerPageState extends ConsumerState<LanguagePickerPage> {
  Language? _left;
  Language? _right;

  bool get _canContinue => _left != null && _right != null && _left != _right;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.chatBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'TalkFlip',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                "Pick the two languages you'll use to talk",
                style: TextStyle(fontSize: 16, color: AppColors.subtleText),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              _LanguageSelector(
                label: 'Your language',
                selected: _left,
                onChanged: (lang) => setState(() => _left = lang),
              ),
              const SizedBox(height: 24),
              _LanguageSelector(
                label: 'Other language',
                selected: _right,
                onChanged: (lang) => setState(() => _right = lang),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _canContinue
                    ? () => ref
                        .read(languagePairProvider.notifier)
                        .setPair(LanguagePair(left: _left!, right: _right!))
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.accent.withValues(alpha: 0.35),
                  disabledForegroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  final String label;
  final Language? selected;
  final ValueChanged<Language?> onChanged;

  const _LanguageSelector({
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: AppColors.subtleText)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.accent, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Language>(
              value: selected,
              isExpanded: true,
              hint: const Text('Select…'),
              items: SupportedLanguages.all.map((lang) {
                return DropdownMenuItem<Language>(
                  value: lang,
                  child: Text(lang.displayName),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
