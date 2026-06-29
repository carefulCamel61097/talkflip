import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// A stable, anonymous per-install identifier, used only to attribute cloud STT
/// usage to a device so the Worker can enforce a per-device monthly minute cap.
///
/// It is a random value generated on first use and stored locally — not tied to
/// any account, hardware identifier, or personal data, and it never changes
/// unless the app's data is cleared. Deliberately not a real credential: it's
/// trivially spoofable, so it's an abuse speed-bump, not authentication (the
/// caps in the Worker are the real guard).
class DeviceId {
  DeviceId._();

  static const _key = 'device_id';
  static String? _cached;

  /// Returns the device id, generating and persisting one on first call. Cached
  /// in memory after the first read so it's instant for every later session.
  static Future<String> get() async {
    final cached = _cached;
    if (cached != null) return cached;

    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_key);
    if (id == null || id.isEmpty) {
      id = _generate();
      await prefs.setString(_key, id);
    }
    _cached = id;
    return id;
  }

  /// A random 128-bit id as 32 lowercase hex chars. `Random.secure()` is a
  /// cryptographic RNG, so cross-install collisions aren't a practical concern.
  /// Not dash-formatted like a UUID — the Worker treats it as an opaque key.
  static String _generate() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
