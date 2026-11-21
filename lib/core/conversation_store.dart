import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/conversation/message.dart';
import 'app_mode.dart';

/// Keeps each mode's conversation on the phone between launches (local only,
/// never synced). Cleared by the top-bar clear button.
///
/// Format (per mode, one shared_preferences key):
/// `{"v":1,"conversations":[{"id":"current","messages":[…]}]}`
/// Only one conversation per mode is used today; the list shape lets a future
/// "saved conversations" feature add more without a migration.
class ConversationStore {
  static String _key(AppMode mode) => 'conversation_${mode.name}';
  static const _currentId = 'current';

  Future<List<Message>> load(AppMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(mode));
    if (raw == null) return const [];
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final conversations = data['conversations'] as List;
      final current = conversations
          .cast<Map<String, dynamic>>()
          .firstWhere((c) => c['id'] == _currentId, orElse: () => const {});
      final messages = (current['messages'] as List?) ?? const [];
      return [
        for (final m in messages) Message.fromJson(m as Map<String, dynamic>),
      ];
    } catch (e) {
      // A corrupt save must never block the app from opening.
      if (kDebugMode) debugPrint('ConversationStore: unreadable save: $e');
      return const [];
    }
  }

  Future<void> save(AppMode mode, List<Message> messages) async {
    final prefs = await SharedPreferences.getInstance();
    if (messages.isEmpty) {
      await prefs.remove(_key(mode));
      return;
    }
    await prefs.setString(
      _key(mode),
      jsonEncode({
        'v': 1,
        'conversations': [
          {
            'id': _currentId,
            'messages': [for (final m in messages) m.toJson()],
          },
        ],
      }),
    );
  }
}

final conversationStoreProvider =
    Provider<ConversationStore>((ref) => ConversationStore());

/// Both modes' saved conversations, loaded once at startup. The router waits
/// for this, so each mode's notifier can read it synchronously when built.
final savedConversationsProvider =
    FutureProvider<Map<AppMode, List<Message>>>((ref) async {
  final store = ref.read(conversationStoreProvider);
  return {
    AppMode.voice: await store.load(AppMode.voice),
    AppMode.text: await store.load(AppMode.text),
  };
});
