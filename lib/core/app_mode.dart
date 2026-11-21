import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The two modes of the main screen. Voice = face-to-face, one phone, mic.
/// Text = chatting in another app: paste their message, type yours.
enum AppMode { voice, text }

/// Last-used mode, persisted so the app reopens where the user left it.
/// Async so the router can wait for it (no voice→text flicker on launch).
class AppModeNotifier extends AsyncNotifier<AppMode> {
  static const _key = 'app_mode';

  @override
  Future<AppMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) == 'text' ? AppMode.text : AppMode.voice;
  }

  Future<void> setMode(AppMode mode) async {
    state = AsyncData(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

final appModeProvider =
    AsyncNotifierProvider<AppModeNotifier, AppMode>(AppModeNotifier.new);
