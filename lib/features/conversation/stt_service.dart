import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Wrapper around speech_to_text with cross-platform silence handling.
///
/// Platform STT engines have inconsistent silence detection — Android's VAD
/// fires `isFinal` after ~0.5–1s of pause (too aggressive), and the Web
/// Speech API never fires it on pause at all. Instead of trusting the
/// platform's `isFinal`, this service runs its own silence timer that resets
/// on every new partial result and fires a synthesised "final" callback after
/// [_silenceThreshold] of no new text.
///
/// Across sessions (Android ends sessions after each utterance), text is
/// accumulated so the consumer sees one continuous draft until our timer
/// fires.
class SttService {
  static const _silenceThreshold = Duration(seconds: 3);

  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  bool _shouldListen = false;
  bool _lastWasError = false;
  String? _currentLocale;
  void Function(String text, bool isFinal)? _onResult;

  Timer? _silenceTimer;
  String _accumulatedText = '';
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
        // Back off after errors so we don't spin in a tight restart loop
        // when the platform recognizer is in a bad state.
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
    _accumulatedText = '';
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
        // Long pauseFor — we manage our own silence threshold so platforms
        // don't preempt us. Android's VAD will still fire isFinal early; we
        // just don't act on it.
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

  String _fullDraft() {
    if (_accumulatedText.isEmpty) return _currentSessionText;
    if (_currentSessionText.isEmpty) return _accumulatedText;
    return '$_accumulatedText $_currentSessionText';
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    final text = result.recognizedWords;
    if (text != _currentSessionText) {
      _currentSessionText = text;
      if (kDebugMode) debugPrint('STT: partial "${_fullDraft()}"');
      _onResult?.call(_fullDraft(), false);
      _resetSilenceTimer();
    }

    if (result.finalResult && _currentSessionText.isNotEmpty) {
      // Platform ended this session. Accumulate and let auto-restart begin
      // the next session via the status callback. Our silence timer keeps
      // running across sessions.
      if (kDebugMode) debugPrint('STT: platform final, accumulating "${_fullDraft()}"');
      _accumulatedText = _fullDraft();
      _currentSessionText = '';
    }
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(_silenceThreshold, _onSilenceTimeout);
  }

  Future<void> _onSilenceTimeout() async {
    final finalText = _fullDraft().trim();
    _accumulatedText = '';
    _currentSessionText = '';

    if (finalText.isNotEmpty) {
      if (kDebugMode) debugPrint('STT: silence timer fired, committing "$finalText"');
      _onResult?.call(finalText, true);
    }

    // Stop the current platform session so the next utterance starts fresh.
    // Auto-restart will resume listening via _handleStatus.
    if (_speech.isListening) {
      try {
        await _speech.stop();
      } catch (_) {}
    }
  }

  Future<void> stopListening() async {
    _shouldListen = false;
    _currentLocale = null;
    _silenceTimer?.cancel();
    _accumulatedText = '';
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
