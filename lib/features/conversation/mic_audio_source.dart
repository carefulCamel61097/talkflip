import 'dart:typed_data';

import 'package:record/record.dart';

/// Captures raw microphone audio as a stream of PCM frames, for the cloud
/// streaming STT engine.
///
/// Output format is **16 kHz, mono, signed 16-bit little-endian PCM**
/// (`AudioEncoder.pcm16bits`) — exactly what Deepgram's streaming endpoint
/// expects as `encoding=linear16&sample_rate=16000&channels=1`. Sending raw
/// PCM avoids any container/codec negotiation on the wire.
///
/// One instance drives one listening turn: [start] opens the mic and returns
/// the byte stream; [stop] closes it. (The on-device engine streams through the
/// platform recognizer instead and never touches this.)
class MicAudioSource {
  /// Deepgram streaming wants these echoed in its query params; keep them here
  /// as the single source of truth for both the recorder and the socket URL.
  static const int sampleRate = 16000;
  static const int numChannels = 1;

  final AudioRecorder _recorder = AudioRecorder();

  /// Whether microphone permission is granted. The conversation layer already
  /// gates activation on `permission_handler`, so callers pass `request: false`
  /// to avoid a second, redundant OS prompt from the recorder.
  Future<bool> hasPermission({bool request = false}) =>
      _recorder.hasPermission(request: request);

  /// Opens the mic and returns a stream of PCM16/16k/mono frames. Each event is
  /// a chunk of raw little-endian 16-bit samples, ready to forward to the STT
  /// socket as-is.
  Future<Stream<Uint8List>> start() {
    return _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: sampleRate,
      numChannels: numChannels,
    ));
  }

  /// Stops the current capture. A no-op if not currently recording, so it's
  /// safe to call on every turn-end / side-switch.
  Future<void> stop() async {
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
  }

  /// Releases the recorder. Call when the owning engine is disposed.
  Future<void> dispose() => _recorder.dispose();
}
