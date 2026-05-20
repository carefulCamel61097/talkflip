import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/supported_languages.dart';

class LanguagePair {
  final Language left;
  final Language right;

  const LanguagePair({required this.left, required this.right});
}

class LanguageRepository {
  static const _leftCodeKey = 'language_pair_left';
  static const _rightCodeKey = 'language_pair_right';

  Future<LanguagePair?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final leftCode = prefs.getString(_leftCodeKey);
    final rightCode = prefs.getString(_rightCodeKey);
    if (leftCode == null || rightCode == null) return null;
    final left = SupportedLanguages.byCode(leftCode);
    final right = SupportedLanguages.byCode(rightCode);
    if (left == null || right == null) return null;
    return LanguagePair(left: left, right: right);
  }

  Future<void> save(LanguagePair pair) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_leftCodeKey, pair.left.code);
    await prefs.setString(_rightCodeKey, pair.right.code);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_leftCodeKey);
    await prefs.remove(_rightCodeKey);
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
