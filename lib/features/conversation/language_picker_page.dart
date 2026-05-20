import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supported_languages.dart';
import '../../core/theme.dart';
import 'language_pair.dart';

class LanguagePickerPage extends ConsumerStatefulWidget {
  /// When non-null, the picker is in "edit" mode: shown above the conversation
  /// via Navigator.push, with the current pair pre-selected, a back button,
  /// and a "Save" button. When null, the picker is first-launch: no AppBar,
  /// "Continue" button.
  final LanguagePair? initialPair;

  const LanguagePickerPage({super.key, this.initialPair});

  @override
  ConsumerState<LanguagePickerPage> createState() => _LanguagePickerPageState();
}

class _LanguagePickerPageState extends ConsumerState<LanguagePickerPage> {
  Language? _left;
  Language? _right;

  bool get _canSave => _left != null && _right != null && _left != _right;
  bool get _isEditing => widget.initialPair != null;

  @override
  void initState() {
    super.initState();
    _left = widget.initialPair?.left;
    _right = widget.initialPair?.right;
  }

  Future<void> _save() async {
    await ref
        .read(languagePairProvider.notifier)
        .setPair(LanguagePair(left: _left!, right: _right!));
    if (!mounted) return;
    // Pop all the way back to the conversation page. In first-launch mode the
    // picker is itself the first route, so popUntil is a no-op and the router
    // handles the transition once the pair is set.
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.chatBackground,
      appBar: _isEditing
          ? AppBar(
              title: const Text('Languages'),
              backgroundColor: AppColors.chatBackground,
              foregroundColor: AppColors.translatedText,
              elevation: 0,
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 32,
            vertical: _isEditing ? 24 : 48,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_isEditing) ...[
                const Text(
                  'ConvoGo',
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
              ],
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
                onPressed: _canSave ? _save : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.accent.withValues(alpha: 0.35),
                  disabledForegroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle:
                      const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                child: Text(_isEditing ? 'Save' : 'Continue'),
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
