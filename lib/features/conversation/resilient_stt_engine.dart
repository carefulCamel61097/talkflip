import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connectivity_provider.dart';
import 'stt_engine.dart';

/// An [SttEngine] that keeps a conversation alive when the cloud engine fails.
///
/// It wraps a [primary] engine (the cloud streamer) and a [fallback] engine
/// (the on-device recogniser). A session normally runs on the primary; if the
/// primary reports `onError` — connection refused, dropped mid-utterance, mic
/// failure — the same session is transparently restarted on the fallback so the
/// speaker just keeps talking. The rest of the app never learns the engine
/// changed underneath it; it only ever sees one [SttEngine].
///
/// Reconnect is lazy and per-turn: each new [startListening] reaches for the
/// primary again, so a transient outage self-heals on the next turn. Two guards
/// keep that from hurting the start-of-turn latency:
///  * if connectivity is known-offline we skip the primary outright (no point
///    paying a connect timeout when nothing can reach the cloud), and
///  * after a primary failure we stay on the fallback for [_cooldown] before
///    retrying, so a cloud outage doesn't re-stall every single turn.
///
/// While a session is running on the fallback, [sttModeProvider] is flipped to
/// [SttMode.fallback] so the UI can show a subtle "basic speech recognition"
/// indicator. When the primary is back in use it flips back to [SttMode.primary].
class ResilientSttEngine implements SttEngine {
  ResilientSttEngine({
    required SttEngine primary,
    required SttEngine fallback,
    required Ref ref,
    Duration cooldown = const Duration(seconds: 30),
  })  : _primary = primary,
        _fallback = fallback,
        _ref = ref,
        _cooldown = cooldown;

  // ignore_for_file: prefer_initializing_formals — named params can't be
  // private, so these public-named params are mapped to the private fields in
  // the initializer list above; the lint's suggested fix doesn't compile here.
  final SttEngine _primary;
  final SttEngine _fallback;
  final Ref _ref;
  final Duration _cooldown;

  /// Monotonic session token. Bumped on every [startListening] and
  /// [stopListening]; the per-session callbacks capture the token they were
  /// started under so a late callback (or a fallback restart) from a session
  /// we've already switched away from is dropped instead of leaking onto the
  /// new side. The decorator-level counterpart of each engine's own guard.
  int _epoch = 0;

  /// The engine currently running (or last run) a session — what [stopListening]
  /// tears down. Null between sessions / after disposal.
  SttEngine? _active;

  /// Set when the primary fails; while true, [startListening] goes straight to
  /// the fallback. Cleared by a [_cooldown] timer so the next turn after it
  /// elapses gives the primary another chance.
  bool _primaryInCooldown = false;
  Timer? _cooldownTimer;

  bool _disposed = false;

  // The active session's callbacks, supplied by the caller (the notifier).
  String? _locale;
  void Function(String text, bool isFinal)? _onResult;
  void Function()? _onSuspended;
  void Function()? _onError;

  @override
  Future<bool> isLocaleAvailable(String locale) {
    // Answer for whichever engine this side would actually use, so the caller's
    // pre-activation hint is accurate: permissive when we're about to try the
    // cloud (no per-device locale gate), but the real on-device check when we
    // already know we'll be on the fallback (offline or in cooldown).
    return _shouldTryPrimary()
        ? _primary.isLocaleAvailable(locale)
        : _fallback.isLocaleAvailable(locale);
  }

  @override
  Future<void> startListening({
    required String locale,
    required void Function(String text, bool isFinal) onResult,
    required void Function() onSuspended,
    required void Function() onError,
  }) async {
    await stopListening();

    _locale = locale;
    _onResult = onResult;
    _onSuspended = onSuspended;
    _onError = onError;

    final epoch = ++_epoch;
    if (_shouldTryPrimary()) {
      await _startOn(_primary, isPrimary: true, epoch: epoch);
    } else {
      await _startOn(_fallback, isPrimary: false, epoch: epoch);
    }
  }

  /// Whether to attempt the cloud engine for the next session. False while a
  /// recent failure is cooling down, or when connectivity reports offline (the
  /// cloud is unreachable anyway, so skip the wasted connect attempt).
  bool _shouldTryPrimary() {
    if (_primaryInCooldown) return false;
    final online = _ref.read(connectivityProvider).value ?? true;
    return online;
  }

  Future<void> _startOn(
    SttEngine engine, {
    required bool isPrimary,
    required int epoch,
  }) async {
    _active = engine;
    _setMode(isPrimary ? SttMode.primary : SttMode.fallback);
    await engine.startListening(
      locale: _locale!,
      // Gate every callback on the epoch: once we've moved on (a new turn, a
      // stop, or a fallback restart that bumped the token), a straggler from
      // the old engine is ignored.
      onResult: (text, isFinal) {
        if (epoch == _epoch) _onResult?.call(text, isFinal);
      },
      onSuspended: () {
        if (epoch == _epoch) _onSuspended?.call();
      },
      onError: () => _handleEngineError(isPrimary: isPrimary, epoch: epoch),
    );
  }

  void _handleEngineError({required bool isPrimary, required int epoch}) {
    if (epoch != _epoch) return; // stale failure from a session we've left
    if (kDebugMode) {
      debugPrint('ResilientSTT: ${isPrimary ? 'primary' : 'fallback'} failed');
    }
    if (isPrimary) {
      // Cloud died — cool it down and restart this same turn on the fallback so
      // the speaker keeps going. The cloud engine has already torn itself down
      // before signalling, so we can start the fallback straight away.
      _primaryInCooldown = true;
      _startCooldownTimer();
      unawaited(_startOn(_fallback, isPrimary: false, epoch: epoch));
    } else {
      // Even the on-device engine couldn't start — nothing left to fall back
      // to. Surface it to the caller, which returns the UI to neutral.
      final cb = _onError;
      unawaited(stopListening());
      cb?.call();
    }
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    // Only clears the cooldown flag; the visible mode stays on whatever engine
    // the current/last session used and is corrected on the next startListening.
    _cooldownTimer = Timer(_cooldown, () => _primaryInCooldown = false);
  }

  void _setMode(SttMode mode) {
    if (_disposed) return;
    _ref.read(sttModeProvider.notifier).set(mode);
  }

  @override
  Future<void> stopListening() async {
    _epoch++; // invalidate in-flight callbacks and any pending fallback restart
    _locale = null;
    _onResult = null;
    _onSuspended = null;
    _onError = null;
    final active = _active;
    _active = null;
    await active?.stopListening();
  }

  @override
  void dispose() {
    _disposed = true;
    _cooldownTimer?.cancel();
    _primary.dispose();
    _fallback.dispose();
  }
}
