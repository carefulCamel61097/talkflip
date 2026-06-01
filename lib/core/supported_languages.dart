class Language {
  /// ISO 639-1 code used by Google Translate (e.g. "en").
  final String code;

  /// Uppercase short label displayed on the language chip (e.g. "EN").
  final String chipLabel;

  /// Full name shown in the picker (e.g. "English").
  final String displayName;

  /// Locale identifier passed to speech_to_text (e.g. "en_US").
  final String sttLocale;

  const Language({
    required this.code,
    required this.chipLabel,
    required this.displayName,
    required this.sttLocale,
  });

  @override
  bool operator ==(Object other) =>
      other is Language && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

class SupportedLanguages {
  SupportedLanguages._();

  /// Curated list — intersection of common speech_to_text locales (iOS +
  /// Android) and Google Translate supported targets. ~15 common languages
  /// for MVP. Add more as needed.
  static const List<Language> all = [
    Language(code: 'en', chipLabel: 'EN', displayName: 'English', sttLocale: 'en_US'),
    Language(code: 'es', chipLabel: 'ES', displayName: 'Spanish', sttLocale: 'es_ES'),
    Language(code: 'fr', chipLabel: 'FR', displayName: 'French', sttLocale: 'fr_FR'),
    Language(code: 'de', chipLabel: 'DE', displayName: 'German', sttLocale: 'de_DE'),
    Language(code: 'it', chipLabel: 'IT', displayName: 'Italian', sttLocale: 'it_IT'),
    Language(code: 'pt', chipLabel: 'PT', displayName: 'Portuguese', sttLocale: 'pt_BR'),
    Language(code: 'nl', chipLabel: 'NL', displayName: 'Dutch', sttLocale: 'nl_NL'),
    Language(code: 'ru', chipLabel: 'RU', displayName: 'Russian', sttLocale: 'ru_RU'),
    Language(code: 'ja', chipLabel: 'JA', displayName: 'Japanese', sttLocale: 'ja_JP'),
    Language(code: 'ko', chipLabel: 'KO', displayName: 'Korean', sttLocale: 'ko_KR'),
    Language(code: 'zh', chipLabel: 'ZH', displayName: 'Mandarin Chinese', sttLocale: 'zh_CN'),
    Language(code: 'ar', chipLabel: 'AR', displayName: 'Arabic', sttLocale: 'ar_SA'),
    Language(code: 'hi', chipLabel: 'HI', displayName: 'Hindi', sttLocale: 'hi_IN'),
    Language(code: 'th', chipLabel: 'TH', displayName: 'Thai', sttLocale: 'th_TH'),
    Language(code: 'sq', chipLabel: 'SQ', displayName: 'Albanian', sttLocale: 'sq_AL'),
  ];

  static Language? byCode(String code) {
    for (final lang in all) {
      if (lang.code == code) return lang;
    }
    return null;
  }
}
