/// Rough, hand-assigned quality tier for a language's on-device speech
/// recognition. See [Language.sttQuality]. It's a static *estimate* derived
/// from Whisper's published per-language WER as a resource proxy — not a live
/// measurement. `low` languages are the candidates to route to cloud STT later
/// (see "Language-specific STT (cloud fallback)" in ROADMAP.md).
enum SttQuality { high, medium, low }

class Language {
  /// ISO 639-1 code used by Google Translate (e.g. "en").
  final String code;

  /// Uppercase short label displayed on the language chip (e.g. "EN").
  final String chipLabel;

  /// Full name shown in the picker (e.g. "English").
  final String displayName;

  /// Locale identifier passed to speech_to_text (e.g. "en_US").
  final String sttLocale;

  /// Estimated quality tier of on-device speech recognition for this language.
  /// Used to triage which languages may need a cloud STT fallback (Phase 2).
  ///
  /// This is a *static estimate*, not a runtime measurement. It's derived from
  /// Whisper's published per-language WER (FLEURS / Common Voice) used as a
  /// rough proxy for how much good training audio a language likely had —
  /// which in turn tracks how well the native recognizers tend to perform.
  /// [SttQuality.low] languages are the ones we expect to route to cloud STT.
  final SttQuality sttQuality;

  const Language({
    required this.code,
    required this.chipLabel,
    required this.displayName,
    required this.sttLocale,
    required this.sttQuality,
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
  ///
  /// `sttQuality` is a static estimate of native on-device STT quality, derived
  /// from Whisper's published per-language WER as a resource proxy. See
  /// [SttQuality]. Roughly: well-resourced majors → high; mid-resource European
  /// and tonal/agglutinative languages → medium; low-resource or dialect-split
  /// languages (the cloud-fallback candidates) → low.
  static const List<Language> all = [
    Language(code: 'en', chipLabel: 'EN', displayName: 'English', sttLocale: 'en_US', sttQuality: SttQuality.high),
    Language(code: 'es', chipLabel: 'ES', displayName: 'Spanish', sttLocale: 'es_ES', sttQuality: SttQuality.high),
    Language(code: 'fr', chipLabel: 'FR', displayName: 'French', sttLocale: 'fr_FR', sttQuality: SttQuality.high),
    Language(code: 'de', chipLabel: 'DE', displayName: 'German', sttLocale: 'de_DE', sttQuality: SttQuality.high),
    Language(code: 'it', chipLabel: 'IT', displayName: 'Italian', sttLocale: 'it_IT', sttQuality: SttQuality.high),
    Language(code: 'pt', chipLabel: 'PT', displayName: 'Portuguese', sttLocale: 'pt_BR', sttQuality: SttQuality.high),
    Language(code: 'nl', chipLabel: 'NL', displayName: 'Dutch', sttLocale: 'nl_NL', sttQuality: SttQuality.high),
    Language(code: 'ru', chipLabel: 'RU', displayName: 'Russian', sttLocale: 'ru_RU', sttQuality: SttQuality.high),
    Language(code: 'ja', chipLabel: 'JA', displayName: 'Japanese', sttLocale: 'ja_JP', sttQuality: SttQuality.high),
    Language(code: 'ko', chipLabel: 'KO', displayName: 'Korean', sttLocale: 'ko_KR', sttQuality: SttQuality.high),
    Language(code: 'zh', chipLabel: 'ZH', displayName: 'Mandarin Chinese', sttLocale: 'zh_CN', sttQuality: SttQuality.high),
    Language(code: 'ar', chipLabel: 'AR', displayName: 'Arabic', sttLocale: 'ar_SA', sttQuality: SttQuality.low),
    Language(code: 'hi', chipLabel: 'HI', displayName: 'Hindi', sttLocale: 'hi_IN', sttQuality: SttQuality.medium),
    Language(code: 'th', chipLabel: 'TH', displayName: 'Thai', sttLocale: 'th_TH', sttQuality: SttQuality.low),
    Language(code: 'tr', chipLabel: 'TR', displayName: 'Turkish', sttLocale: 'tr_TR', sttQuality: SttQuality.medium),
    Language(code: 'pl', chipLabel: 'PL', displayName: 'Polish', sttLocale: 'pl_PL', sttQuality: SttQuality.high),
    Language(code: 'uk', chipLabel: 'UK', displayName: 'Ukrainian', sttLocale: 'uk_UA', sttQuality: SttQuality.high),
    Language(code: 'ro', chipLabel: 'RO', displayName: 'Romanian', sttLocale: 'ro_RO', sttQuality: SttQuality.medium),
    Language(code: 'cs', chipLabel: 'CS', displayName: 'Czech', sttLocale: 'cs_CZ', sttQuality: SttQuality.medium),
    Language(code: 'sk', chipLabel: 'SK', displayName: 'Slovak', sttLocale: 'sk_SK', sttQuality: SttQuality.medium),
    Language(code: 'hu', chipLabel: 'HU', displayName: 'Hungarian', sttLocale: 'hu_HU', sttQuality: SttQuality.medium),
    Language(code: 'el', chipLabel: 'EL', displayName: 'Greek', sttLocale: 'el_GR', sttQuality: SttQuality.medium),
    Language(code: 'da', chipLabel: 'DA', displayName: 'Danish', sttLocale: 'da_DK', sttQuality: SttQuality.medium),
    Language(code: 'sv', chipLabel: 'SV', displayName: 'Swedish', sttLocale: 'sv_SE', sttQuality: SttQuality.high),
    Language(code: 'no', chipLabel: 'NO', displayName: 'Norwegian', sttLocale: 'nb_NO', sttQuality: SttQuality.medium),
    Language(code: 'fi', chipLabel: 'FI', displayName: 'Finnish', sttLocale: 'fi_FI', sttQuality: SttQuality.medium),
    Language(code: 'hr', chipLabel: 'HR', displayName: 'Croatian', sttLocale: 'hr_HR', sttQuality: SttQuality.medium),
    Language(code: 'id', chipLabel: 'ID', displayName: 'Indonesian', sttLocale: 'id_ID', sttQuality: SttQuality.high),
    Language(code: 'ms', chipLabel: 'MS', displayName: 'Malay', sttLocale: 'ms_MY', sttQuality: SttQuality.low),
    Language(code: 'vi', chipLabel: 'VI', displayName: 'Vietnamese', sttLocale: 'vi_VN', sttQuality: SttQuality.medium),
    Language(code: 'ca', chipLabel: 'CA', displayName: 'Catalan', sttLocale: 'ca_ES', sttQuality: SttQuality.high),
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
