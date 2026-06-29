import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/config.dart';
import 'mic_audio_source.dart';
import 'stt_engine.dart';

/// Cloud [SttEngine]: streams microphone audio to the Worker's `/stt-stream`
/// relay (Deepgram behind it) and turns the streaming transcript JSON back into
/// the same `onResult(text, isFinal)` the rest of the app already consumes — so
/// the draft bubble, commit, and side-switching all work unchanged.
///
/// Both the live draft and the commit come from the provider: interim results
/// (`is_final == false`) stream the draft; `speech_final == true` (Deepgram's
/// endpointing fired on end-of-speech) commits the turn. Deepgram may finalize
/// a long utterance in several `is_final` chunks whose transcript resets each
/// time, so [_finalized] stitches them and the sentence keeps its earlier words.
class CloudSttEngine implements SttEngine {
  static const _suspendThreshold = Duration(seconds: 60);
  static const _model = 'nova-3';

  final MicAudioSource _mic = MicAudioSource();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _wsSub;
  StreamSubscription<Uint8List>? _micSub;
  Timer? _suspendTimer;

  void Function(String text, bool isFinal)? _onResult;
  void Function()? _onSuspended;

  /// True between [startListening] and [stopListening]. Gates every async
  /// callback so a straggler from a torn-down session can't reach the app — the
  /// cloud counterpart of the on-device generation guard. [stopListening] also
  /// closes the socket, so stragglers can't even be produced.
  bool _listening = false;

  /// Finalized segment text accumulated within the current turn (see class doc).
  String _finalized = '';

  @override
  Future<bool> isLocaleAvailable(String locale) async {
    // Cloud STT isn't gated on a device-installed language pack, so there is no
    // "not installed" failure mode to warn about here. Whether the provider
    // supports a language is a static fact carried by the language list, not a
    // per-device check.
    return true;
  }

  @override
  Future<void> startListening({
    required String locale,
    required void Function(String text, bool isFinal) onResult,
    required void Function() onSuspended,
  }) async {
    await stopListening();

    _onResult = onResult;
    _onSuspended = onSuspended;
    _finalized = '';
    _listening = true;

    final uri = Uri.parse(AppConfig.sttStreamUrl).replace(queryParameters: {
      'lang': _deepgramLang(locale),
      'model': _model,
    });

    final WebSocketChannel channel;
    try {
      channel = WebSocketChannel.connect(uri);
      _channel = channel;
      await channel.ready;
    } catch (e) {
      if (kDebugMode) debugPrint('CloudSTT: connect failed: $e');
      final cb = _onSuspended;
      await stopListening();
      cb?.call();
      return;
    }

    if (!_listening) return; // stopped while connecting

    _wsSub = channel.stream.listen(
      _handleMessage,
      onError: (Object e) => _handleDisconnect('ws error: $e'),
      onDone: () => _handleDisconnect('ws closed'),
      cancelOnError: true,
    );

    try {
      final micStream = await _mic.start();
      if (!_listening) {
        await _mic.stop();
        return;
      }
      _micSub = micStream.listen((frame) {
        if (!_listening) return;
        try {
          _channel?.sink.add(frame);
        } catch (_) {/* socket closing */}
      });
    } catch (e) {
      if (kDebugMode) debugPrint('CloudSTT: mic start failed: $e');
      final cb = _onSuspended;
      await stopListening();
      cb?.call();
      return;
    }

    _resetSuspendTimer();
  }

  void _handleMessage(dynamic raw) {
    if (!_listening) return;
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return; // non-JSON / binary frame; ignore
    }
    if (data['type'] != 'Results') return;

    final alts = (data['channel'] as Map<String, dynamic>?)?['alternatives'];
    final transcript = (alts is List && alts.isNotEmpty)
        ? ((alts.first as Map<String, dynamic>)['transcript'] as String? ?? '')
        : '';
    final isFinal = data['is_final'] == true;
    final speechFinal = data['speech_final'] == true;

    if (transcript.isEmpty && !speechFinal) return;
    if (transcript.isNotEmpty) _resetSuspendTimer();

    if (isFinal) {
      if (transcript.isNotEmpty) {
        _finalized =
            _finalized.isEmpty ? transcript : '$_finalized $transcript';
      }
      if (speechFinal) {
        final full = _finalized.trim();
        _finalized = '';
        if (full.isNotEmpty) _onResult?.call(full, true); // commit the turn
      } else {
        // A segment finalized mid-utterance; show the accumulated draft.
        _onResult?.call(_finalized.trim(), false);
      }
    } else {
      final draft =
          _finalized.isEmpty ? transcript : '$_finalized $transcript';
      _onResult?.call(draft.trim(), false);
    }
  }

  void _handleDisconnect(String reason) {
    if (!_listening) return; // intentional teardown
    if (kDebugMode) debugPrint('CloudSTT: disconnected ($reason)');
    // Treat an unexpected drop like a suspend: return the UI to neutral rather
    // than leaving a hot, dead session. Reconnect / offline UX is a later step.
    final cb = _onSuspended;
    unawaited(stopListening());
    cb?.call();
  }

  void _resetSuspendTimer() {
    _suspendTimer?.cancel();
    _suspendTimer = Timer(_suspendThreshold, () {
      final cb = _onSuspended;
      unawaited(stopListening());
      cb?.call();
    });
  }

  @override
  Future<void> stopListening() async {
    _listening = false;
    _onResult = null;
    _onSuspended = null;
    _finalized = '';
    _suspendTimer?.cancel();
    _suspendTimer = null;

    await _micSub?.cancel();
    _micSub = null;
    try {
      await _mic.stop();
    } catch (_) {}

    await _wsSub?.cancel();
    _wsSub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  @override
  void dispose() {
    unawaited(stopListening());
    unawaited(_mic.dispose());
  }

  /// Deepgram language code for a `speech_to_text` locale. Deepgram keys on the
  /// language subtag for the languages we ship (e.g. "en_US" -> "en",
  /// "th_TH" -> "th"); a regional variant can be added here if testing shows a
  /// language needs one.
  static String _deepgramLang(String locale) {
    final sep = locale.indexOf(RegExp(r'[_-]'));
    final lang = sep == -1 ? locale : locale.substring(0, sep);
    return lang.toLowerCase();
  }
}
