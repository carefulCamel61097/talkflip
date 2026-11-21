import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/supported_languages.dart';

/// The two languages of a conversation.
///
/// Screen layout follows the WhatsApp convention: the other person ("theirs")
/// is on the LEFT, you ("mine") are on the RIGHT — in both voice and text mode.
/// [left]/[right] are the screen positions; [mine]/[theirs] are who it is.
class LanguagePair {
  /// Your language ("Your language" in the picker). Shown on the right.
  final Language mine;

  /// The other person's language. Shown on the left.
  final Language theirs;

  const LanguagePair({required this.mine, required this.theirs});

  Language get left => theirs;
  Language get right => mine;
}

class LanguageRepository {
  // Key names predate the you-on-the-right layout: "left" has always held
  // *your* language (the picker's first slot). Kept as-is so existing installs
  // need no migration — only the on-screen position changed.
  static const _mineCodeKey = 'language_pair_left';
  static const _theirsCodeKey = 'language_pair_right';

  Future<LanguagePair?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final mineCode = prefs.getString(_mineCodeKey);
    final theirsCode = prefs.getString(_theirsCodeKey);
    if (mineCode == null || theirsCode == null) return null;
    final mine = SupportedLanguages.byCode(mineCode);
    final theirs = SupportedLanguages.byCode(theirsCode);
    if (mine == null || theirs == null) return null;
    return LanguagePair(mine: mine, theirs: theirs);
  }

  Future<void> save(LanguagePair pair) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mineCodeKey, pair.mine.code);
    await prefs.setString(_theirsCodeKey, pair.theirs.code);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_mineCodeKey);
    await prefs.remove(_theirsCodeKey);
  }
}

final languageRepositoryProvider =
    Provider<LanguageRepository>((ref) => LanguageRepository());

class LanguagePairNotifier extends AsyncNotifier<LanguagePair?> {
  @override
  Future<LanguagePair?> build() async {
    final repo = ref.read(languageRepositoryProvider);
    return repo.load();
  }

  Future<void> setPair(LanguagePair pair) async {
    state = AsyncData(pair);
    final repo = ref.read(languageRepositoryProvider);
    await repo.save(pair);
  }
}

final languagePairProvider =
    AsyncNotifierProvider<LanguagePairNotifier, LanguagePair?>(
  LanguagePairNotifier.new,
);
