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

  /// Supported languages = intersection of Apple `SFSpeechRecognizer`
  /// published locales (the stricter STT platform) and Google Translate
  /// codes, so we can be confident they work on most devices without
  /// per-language manual testing. One STT locale per language.
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
    Language(code: 'tr', chipLabel: 'TR', displayName: 'Turkish', sttLocale: 'tr_TR'),
    Language(code: 'pl', chipLabel: 'PL', displayName: 'Polish', sttLocale: 'pl_PL'),
    Language(code: 'uk', chipLabel: 'UK', displayName: 'Ukrainian', sttLocale: 'uk_UA'),
    Language(code: 'ro', chipLabel: 'RO', displayName: 'Romanian', sttLocale: 'ro_RO'),
    Language(code: 'cs', chipLabel: 'CS', displayName: 'Czech', sttLocale: 'cs_CZ'),
    Language(code: 'sk', chipLabel: 'SK', displayName: 'Slovak', sttLocale: 'sk_SK'),
    Language(code: 'hu', chipLabel: 'HU', displayName: 'Hungarian', sttLocale: 'hu_HU'),
    Language(code: 'el', chipLabel: 'EL', displayName: 'Greek', sttLocale: 'el_GR'),
    Language(code: 'da', chipLabel: 'DA', displayName: 'Danish', sttLocale: 'da_DK'),
    Language(code: 'sv', chipLabel: 'SV', displayName: 'Swedish', sttLocale: 'sv_SE'),
    Language(code: 'no', chipLabel: 'NO', displayName: 'Norwegian', sttLocale: 'nb_NO'),
    Language(code: 'fi', chipLabel: 'FI', displayName: 'Finnish', sttLocale: 'fi_FI'),
    Language(code: 'hr', chipLabel: 'HR', displayName: 'Croatian', sttLocale: 'hr_HR'),
    Language(code: 'id', chipLabel: 'ID', displayName: 'Indonesian', sttLocale: 'id_ID'),
    Language(code: 'ms', chipLabel: 'MS', displayName: 'Malay', sttLocale: 'ms_MY'),
    Language(code: 'vi', chipLabel: 'VI', displayName: 'Vietnamese', sttLocale: 'vi_VN'),
    Language(code: 'ca', chipLabel: 'CA', displayName: 'Catalan', sttLocale: 'ca_ES'),
  ];

  /// Codes pinned in the picker's "Common languages" section, in display
  /// order. Thai included by request.
  static const List<String> commonCodes = [
    'en', 'es', 'fr', 'de', 'zh', 'ja', 'ar', 'hi', 'pt', 'ru', 'th',
  ];

  /// The common languages as objects, in [commonCodes] order.
  static List<Language> get common =>
      commonCodes.map(byCode).whereType<Language>().toList();

  /// All languages sorted alphabetically by display name, for the picker's
  /// full list.
  static List<Language> get alphabetical =>
      [...all]..sort((a, b) => a.displayName.compareTo(b.displayName));

  static Language? byCode(String code) {
    for (final lang in all) {
      if (lang.code == code) return lang;
    }
    return null;
  }
}
