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
  void Function(String text, bool isFinal)? _onResult;
  void Function()? _onSuspended;

  Timer? _silenceTimer;
  Timer? _suspendTimer;
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
    required void Function() onSuspended,
  }) async {
    final ok = await _ensureInitialized();
    if (!ok) return;
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
