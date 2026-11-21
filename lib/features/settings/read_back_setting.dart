import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Text mode: show what your translation says when translated back into your
/// language ("Reads back as: …"), so you can catch a bad translation before
/// sending it. Costs one extra translation per message you send.
///
/// Default ON (decided 2026-11-21 after hands-on testing). An earlier worry
/// was that an identical read-back would confuse newcomers; that's solved by
/// hiding it whenever it matches what you typed (see [readBackDiffers]), so it
/// only appears when it can actually tell you something.
class ReadBackNotifier extends AsyncNotifier<bool> {
  static const _key = 'read_back';
  static const defaultValue = true;

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? defaultValue;
  }

  Future<void> set(bool enabled) async {
    state = AsyncData(enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }
}

final readBackProvider =
    AsyncNotifierProvider<ReadBackNotifier, bool>(ReadBackNotifier.new);

/// Synchronous view for UI and notifiers: the saved value once loaded,
/// the default until then.
bool readBackEnabled(Ref ref) =>
    ref.read(readBackProvider).value ?? ReadBackNotifier.defaultValue;

/// Whether a read-back says something meaningfully different from what you
/// wrote. Ignores case, punctuation and spacing, so "Yes! See you at 7." and
/// "yes, see you at 7" count as the same and the line stays hidden — it only
/// appears when it can actually tell you something.
bool readBackDiffers(String original, String readBack) {
  String norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
  return norm(original) != norm(readBack);
}
