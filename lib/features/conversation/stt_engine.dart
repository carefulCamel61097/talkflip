import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'on_device_stt_engine.dart';

/// The speech-to-text engine the rest of the app talks to. Everything
/// downstream — the live draft bubble, commit-on-final, side-switching — only
/// ever sees the [onResult] callback, never the engine internals. That single
/// seam is what lets us swap the concrete engine (native on-device today, a
/// cloud streaming engine later) without touching the conversation layer.
abstract class SttEngine {
  /// Whether this engine can recognise [locale]'s language on this device.
  /// Implementations are permissive on uncertainty (return true when they
  /// can't determine support) so activation is never blocked by a check that
  /// couldn't actually run.
  Future<bool> isLocaleAvailable(String locale);

  /// Starts a listening session for [locale]. [onResult] is called with
  /// streaming partials (`isFinal == false`) as words arrive and once with the
  /// committed text (`isFinal == true`) when the utterance ends. [onSuspended]
  /// fires when the engine gives up after a long idle so the caller can return
  /// to neutral.
  Future<void> startListening({
    required String locale,
    required void Function(String text, bool isFinal) onResult,
    required void Function() onSuspended,
  });

  /// Stops the current session, discarding any in-flight result so a straggler
  /// can't leak onto a newly-activated side.
  Future<void> stopListening();

  /// Releases engine resources.
  void dispose();
}

/// The active STT engine for the app. On-device today; a later milestone will
/// select a cloud streaming engine here (behind a config flag). Centralising
/// the choice in one provider keeps the swap a one-line change and lets tests
/// override the engine.
final sttEngineProvider = Provider<SttEngine>((ref) {
  final engine = OnDeviceSttEngine();
  ref.onDispose(engine.dispose);
  return engine;
});
