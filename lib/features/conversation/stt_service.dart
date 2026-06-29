import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Wrapper around speech_to_text with cross-platform commit behavior and a
/// long-idle suspend.
///
/// Commit strategy: whichever fires first wins —
/// 1. Platform `isFinal=true` (Android's VAD fires after ~1s pause; iOS rarely
///    from pauses; Web never from pauses).
/// 2. Our [_silenceThreshold] fallback timer (resets on every new partial).
///
/// Suspend strategy: after [_suspendThreshold] of no new speech at all, the
/// service stops listening entirely and invokes the `onSuspended` callback
/// so the consumer (ConversationNotifier) can return to neutral. Battery
/// saver + matches the design that the mic shouldn't sit hot forever.
class SttService {
  static const _silenceThreshold = Duration(seconds: 3);
  static const _suspendThreshold = Duration(seconds: 60);

  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  bool _shouldListen = false;
  bool _lastWasError = false;
  String? _currentLocale;

  /// Cached lowercase language subtags the device recogniser supports (e.g.
  /// {"en", "fr", "th"}). Populated lazily on the first availability check and
  /// reused for the session — see [_installedLanguageSubtags].
  List<String>? _installedSubtags;

  void Function(String text, bool isFinal)? _onResult;
  void Function()? _onSuspended;

  Timer? _silenceTimer;
  Timer? _suspendTimer;
  String _currentSessionText = '';

  /// Monotonic session generation. Bumped on every [startListening] and
  /// [stopListening] so that a result callback from a superseded native
  /// session (e.g. the old side's final arriving *after* the user switched)
  /// can be dropped before it ever reaches [_onResult] and lands on the wrong
  /// side. Each native `listen` captures the generation it was started under.
  int _sessionGen = 0;

  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;
    try {
      _initialized = await _speech.initialize(
        onStatus: _handleStatus,
        onError: (error) {
          _lastWasError = true;
          if (kDebugMode) debugPrint('STT error: ${error.errorMsg}');
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('STT init failed: $e');
      _initialized = false;
    }
    return _initialized;
  }

  void _handleStatus(String status) {
    if (status == 'notListening' && _shouldListen) {
      if (_lastWasError) {
        _lastWasError = false;
        Timer(const Duration(milliseconds: 500), _start);
      } else {
        _start();
      }
    }
  }

  /// Whether the device has a speech-recognition locale matching [locale]'s
  /// language (e.g. any Thai locale for "th_TH"). Matching is on the language
  /// subtag, not the region, because what the user installs/enables is the
  /// language pack — the region variant rarely matters for whether speech is
  /// recognised at all.
  ///
  /// Permissive on uncertainty: if STT can't initialize, the call throws, or
  /// the platform reports no locales (e.g. Web, or a list that hasn't been
  /// populated yet), this returns true so we never block activation on a check
  /// we couldn't actually perform. A false result means "we are confident this
  /// language's recogniser isn't installed".
  Future<bool> isLocaleAvailable(String locale) async {
    // Web's recognizer locale list (Chrome's Web Speech API) is unreliable: it
    // under-reports, omitting languages it can actually recognise. Web is
    // dev-only and won't ship, so never gate activation on it — only the
    // native iOS/Android lists reflect a device's real recogniser support.
    if (kIsWeb) return true;
    final subtags = await _installedLanguageSubtags();
    // Permissive on uncertainty (init failed / threw / empty list): a null or
    // empty result means we couldn't determine support, so don't block.
    if (subtags == null || subtags.isEmpty) return true;
    return subtags.contains(_languageSubtag(locale));
  }

  /// Language subtags the device recogniser supports, fetched once and cached.
  ///
  /// Cached because the installed recogniser languages don't change within a
  /// session, and because the first availability check happens from the neutral
  /// state (no live session) — so the one `locales()` platform call never races
  /// a mid-sentence side-switch. Returns null when support can't be determined.
  Future<List<String>?> _installedLanguageSubtags() async {
    if (_installedSubtags != null) return _installedSubtags;
    final ok = await _ensureInitialized();
    if (!ok) return null;
    try {
      final locales = await _speech.locales();
      if (locales.isEmpty) return null;
      _installedSubtags =
          locales.map((l) => _languageSubtag(l.localeId)).toList(growable: false);
      return _installedSubtags;
    } catch (e) {
      if (kDebugMode) debugPrint('STT locales() check failed: $e');
      return null;
    }
  }

  /// Extracts the lowercase language subtag from a locale id, tolerating both
  /// "en_US" and "en-US" forms (speech_to_text reports either by platform).
  static String _languageSubtag(String locale) {
    final sep = locale.indexOf(RegExp(r'[_-]'));
    final lang = sep == -1 ? locale : locale.substring(0, sep);
    return lang.toLowerCase();
  }

  Future<void> startListening({
    required String locale,
    required void Function(String text, bool isFinal) onResult,
    required void Function() onSuspended,
  }) async {
    final ok = await _ensureInitialized();
    if (!ok) return;
    // New session generation: any in-flight callback from a prior session is
    // now stale and will be dropped by _onSpeechResult's generation check.
    _sessionGen++;
    _currentLocale = locale;
    _onResult = onResult;
    _onSuspended = onSuspended;
    _shouldListen = true;
    _currentSessionText = '';
    _silenceTimer?.cancel();
    _resetSuspendTimer();
    await _start();
  }

  Future<void> _start() async {
    if (!_shouldListen || _currentLocale == null) return;
    if (_speech.isListening) return;
    _currentSessionText = '';
    // Capture the generation this native session belongs to. Auto-restarts
    // (via _handleStatus) keep the same generation; only start/stopListening
    // advance it. Results carry this generation so stale ones get dropped.
    final gen = _sessionGen;
    if (kDebugMode) debugPrint('STT: starting session (locale=$_currentLocale)');
    try {
      await _speech.listen(
        onResult: (result) => _onSpeechResult(result, gen),
        localeId: _currentLocale,
        listenFor: const Duration(minutes: 30),
        pauseFor: const Duration(seconds: 30),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenMode: ListenMode.dictation,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('STT listen failed: $e');
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result, int gen) {
    // Drop results from a superseded session. This is the real guard against
    // the old side's final arriving after a switch: without it, that final is
    // delivered to the current _onResult and commits to the wrong side.
    if (gen != _sessionGen) return;
    final text = result.recognizedWords;
    if (text.isNotEmpty && text != _currentSessionText) {
      _currentSessionText = text;
      if (kDebugMode) debugPrint('STT: partial "$_currentSessionText"');
      _onResult?.call(_currentSessionText, false);
      _resetSilenceTimer();
      _resetSuspendTimer();
    }

    if (result.finalResult) {
      if (kDebugMode) debugPrint('STT: platform final, committing "$_currentSessionText"');
      _commitCurrent();
    }
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(_silenceThreshold, _onSilenceTimeout);
  }

  void _resetSuspendTimer() {
    _suspendTimer?.cancel();
    _suspendTimer = Timer(_suspendThreshold, _onSuspendTimeout);
  }

  Future<void> _onSilenceTimeout() async {
    if (kDebugMode) debugPrint('STT: silence timer fired, committing "$_currentSessionText"');
    _commitCurrent();
    if (_speech.isListening) {
      try {
        await _speech.stop();
      } catch (_) {}
    }
  }

  Future<void> _onSuspendTimeout() async {
    if (kDebugMode) {
      debugPrint('STT: mic suspended after ${_suspendThreshold.inSeconds}s of silence');
    }
    final callback = _onSuspended;
    await stopListening();
    callback?.call();
  }

  void _commitCurrent() {
    final text = _currentSessionText.trim();
    _silenceTimer?.cancel();
    _currentSessionText = '';
    if (text.isNotEmpty) {
      _onResult?.call(text, true);
    }
  }

  Future<void> stopListening() async {
    _shouldListen = false;
    _currentLocale = null;
    // Advance the generation so any result the dying session still emits
    // (notably the final from _speech.stop()) is dropped by _onSpeechResult —
    // even if it arrives after the next session has already started and
    // reassigned _onResult. Detaching _onResult too is belt-and-suspenders.
    _sessionGen++;
    _onResult = null;
    _onSuspended = null;
    _silenceTimer?.cancel();
    _suspendTimer?.cancel();
    _currentSessionText = '';
    if (_speech.isListening) {
      try {
        await _speech.stop();
      } catch (e) {
        if (kDebugMode) debugPrint('STT stop failed: $e');
      }
    }
  }

  void dispose() {
    _shouldListen = false;
    _currentLocale = null;
    _silenceTimer?.cancel();
    _suspendTimer?.cancel();
    try {
      _speech.cancel();
    } catch (_) {}
  }
}
