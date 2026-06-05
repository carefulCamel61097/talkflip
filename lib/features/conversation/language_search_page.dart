import 'package:flutter/material.dart';

import '../../core/supported_languages.dart';
import '../../core/theme.dart';

/// Full-screen searchable language picker. Pushed from a [_LanguageSelector]
/// tap; pops with the chosen [Language] (or null if dismissed).
///
/// Layout: a search field filters the full list by display name or chip code.
/// With an empty query it shows a pinned "Common languages" section followed
/// by the full alphabetical list. [excludeCode] (the other side's current
/// pick) is omitted so the same language can't be chosen for both sides.
class LanguageSearchPage extends StatefulWidget {
  final String? selectedCode;
  final String? excludeCode;

  const LanguageSearchPage({super.key, this.selectedCode, this.excludeCode});

  @override
  State<LanguageSearchPage> createState() => _LanguageSearchPageState();
}

class _LanguageSearchPageState extends State<LanguageSearchPage> {
  String _query = '';

  List<Language> get _selectable => SupportedLanguages.all
      .where((l) => l.code != widget.excludeCode)
      .toList();

  bool _matches(Language l, String q) =>
      l.displayName.toLowerCase().contains(q) ||
      l.chipLabel.toLowerCase().contains(q) ||
      l.code.toLowerCase().contains(q);

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final excluded = widget.excludeCode;

    return Scaffold(
      backgroundColor: AppColors.chatBackground,
      appBar: AppBar(
        title: const Text('Choose a language'),
        backgroundColor: AppColors.chatBackground,
        foregroundColor: AppColors.translatedText,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                autofocus: false,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Search languages',
                  prefixIcon: const Icon(Icons.search, color: AppColors.subtleText),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: AppColors.accent.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.accent, width: 2),
                  ),
                ),
              ),
            ),
            Expanded(
              child: q.isEmpty
                  ? _sectionedList(excluded)
                  : _filteredList(q, excluded),
            ),
          ],
        ),
      ),
    );
  }

  /// Empty query: pinned "Common" section then the full alphabetical list.
  Widget _sectionedList(String? excluded) {
    final common = SupportedLanguages.common
        .where((l) => l.code != excluded)
        .toList();
    final all = SupportedLanguages.alphabetical
        .where((l) => l.code != excluded)
        .toList();

    return ListView(
      children: [
        _sectionHeader('Common languages'),
        ...common.map(_tile),
        _sectionHeader('All languages'),
        ...all.map(_tile),
      ],
    );
  }

  Widget _filteredList(String q, String? excluded) {
    final results = _selectable.where((l) => _matches(l, q)).toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    if (results.isEmpty) {
      return const Center(
        child: Text('No matches', style: TextStyle(color: AppColors.subtleText)),
      );
    }
    return ListView(children: results.map(_tile).toList());
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: AppColors.subtleText,
        ),
      ),
    );
  }

  Widget _tile(Language lang) {
    final isSelected = lang.code == widget.selectedCode;
    return ListTile(
      title: Text(lang.displayName, style: AppTextStyles.translated.copyWith(fontSize: 17)),
      leading: SizedBox(
        width: 36,
        child: Text(
          lang.chipLabel,
          style: AppTextStyles.languageChip.copyWith(
            fontSize: 13,
            color: AppColors.accent,
          ),
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: AppColors.accent)
          : null,
      onTap: () => Navigator.pop<Language>(context, lang),
    );
  }
}
