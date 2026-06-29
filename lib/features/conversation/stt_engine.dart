import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import 'cloud_stt_engine.dart';
import 'on_device_stt_engine.dart';
import 'resilient_stt_engine.dart';

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
  /// fires when the engine gives up after a long *idle* so the caller can
  /// return to neutral. [onError] fires when the session ends because the engine
  /// *failed* (e.g. the cloud connection dropped or couldn't be established) —
  /// distinct from a quiet timeout. Splitting the two lets a wrapper fall back
  /// to another engine on failure while still treating idle as plain neutral.
  Future<void> startListening({
    required String locale,
    required void Function(String text, bool isFinal) onResult,
    required void Function() onSuspended,
    required void Function() onError,
  });

  /// Stops the current session, discarding any in-flight result so a straggler
  /// can't leak onto a newly-activated side.
  Future<void> stopListening();

  /// Releases engine resources.
  void dispose();
}

/// The active STT engine for the app, chosen by [AppConfig.useCloudStt].
/// Centralising the choice (and disposal) here keeps the swap a one-line flag
/// and lets tests override the engine.
///
/// In cloud mode the engine is wrapped in a [ResilientSttEngine] so a dropped
/// or unreachable cloud connection transparently falls back to the on-device
/// recogniser instead of going dead. On-device mode needs no wrapper.
final sttEngineProvider = Provider<SttEngine>((ref) {
  final SttEngine engine = AppConfig.useCloudStt
      ? ResilientSttEngine(
          primary: CloudSttEngine(),
          fallback: OnDeviceSttEngine(),
          ref: ref,
        )
      : OnDeviceSttEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

/// Which STT engine is currently serving the conversation. [SttMode.fallback]
/// means the cloud engine failed and we've dropped to the on-device recogniser;
/// the UI surfaces a subtle "basic speech recognition" indicator for it. Only
/// [ResilientSttEngine] writes this; everyone else just reads.
enum SttMode { primary, fallback }

class SttModeNotifier extends Notifier<SttMode> {
  @override
  SttMode build() => SttMode.primary;

  void set(SttMode mode) => state = mode;
}

final sttModeProvider =
    NotifierProvider<SttModeNotifier, SttMode>(SttModeNotifier.new);
