import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Wrapper around speech_to_text with cross-platform commit behavior.
///
/// Commit strategy: whichever fires first wins —
/// 1. Platform `isFinal=true` (Android's VAD fires after ~1s pause; iOS rarely
///    from pauses; Web never from pauses).
/// 2. Our own [_silenceThreshold] fallback timer (resets on every new partial).
///
/// Net effect: Android commits bubbles on natural ~1s pauses, iOS/Web on our
/// 3s timer. Android's auto-restart gap (~100-500ms between sessions) may
/// clip the first word or two of an immediately-resumed utterance — accepted
/// platform limitation; the visible bubble-commit at least signals to users
/// that they should pause briefly before continuing.
class SttService {
  static const _silenceThreshold = Duration(seconds: 3);

  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  bool _shouldListen = false;
  bool _lastWasError = false;
  String? _currentLocale;
  void Function(String text, bool isFinal)? _onResult;

  Timer? _silenceTimer;
  String _currentSessionText = '';

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

  Future<void> startListening({
    required String locale,
    required void Function(String text, bool isFinal) onResult,
  }) async {
    final ok = await _ensureInitialized();
    if (!ok) return;
    _currentLocale = locale;
    _onResult = onResult;
    _shouldListen = true;
    _currentSessionText = '';
    _silenceTimer?.cancel();
    await _start();
  }

  Future<void> _start() async {
    if (!_shouldListen || _currentLocale == null) return;
    if (_speech.isListening) return;
    _currentSessionText = '';
    if (kDebugMode) debugPrint('STT: starting session (locale=$_currentLocale)');
    try {
      await _speech.listen(
        onResult: _onSpeechResult,
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

  void _onSpeechResult(SpeechRecognitionResult result) {
    final text = result.recognizedWords;
    // Guard: don't let an empty isFinal wipe out a non-empty partial state.
    if (text.isNotEmpty && text != _currentSessionText) {
      _currentSessionText = text;
      if (kDebugMode) debugPrint('STT: partial "$_currentSessionText"');
      _onResult?.call(_currentSessionText, false);
      _resetSilenceTimer();
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

  Future<void> _onSilenceTimeout() async {
    if (kDebugMode) debugPrint('STT: silence timer fired, committing "$_currentSessionText"');
    _commitCurrent();
    // Stop and let auto-restart begin a fresh session.
    if (_speech.isListening) {
      try {
        await _speech.stop();
      } catch (_) {}
    }
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
    _silenceTimer?.cancel();
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
    try {
      _speech.cancel();
    } catch (_) {}
  }
}
