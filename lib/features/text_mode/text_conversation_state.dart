import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_mode.dart';
import '../../core/conversation_store.dart';
import '../conversation/language_pair.dart';
import '../conversation/message.dart';
import '../conversation/translation_service.dart';
import '../settings/read_back_setting.dart';

/// Text-mode conversation: their pasted messages (left) and your typed ones
/// (right), each translated into the other language. Separate from the voice
/// conversation — each mode keeps its own history.
class TextConversationNotifier extends Notifier<List<Message>> {
  int _nextId = 0;

  @override
  List<Message> build() {
    // Restore the saved text conversation and keep saving on every change.
    final saved =
        ref.read(savedConversationsProvider).value?[AppMode.text] ?? const [];
    _nextId = saved.isEmpty ? 0 : saved.map((m) => m.id).reduce(max) + 1;
    final store = ref.read(conversationStoreProvider);
    listenSelf((previous, next) {
      if (!identical(previous, next)) store.save(AppMode.text, next);
    });
    return saved;
  }

  LanguagePair? get _pair => ref.read(languagePairProvider).value;

  /// Adds the other person's message (pasted) and translates it into yours.
  Future<String?> addTheirs(String text) => _add(text, isLeft: true);

  /// Adds your message and translates it into theirs. Completes with the
  /// translation (so the page can copy it to the clipboard), or null if
  /// translation failed.
  Future<String?> sendMine(String text) => _add(text, isLeft: false);

  Future<String?> _add(String raw, {required bool isLeft}) async {
    final text = raw.trim();
    if (text.isEmpty || _pair == null) return null;
    final id = _nextId++;
    state = [
      ...state,
      Message(id: id, originalText: text, translatedText: null, isLeft: isLeft),
    ];
    return _translate(id);
  }

  Future<String?> retry(int id) async {
    _replace(id, (m) => m.withTranslation(translatedText: null));
    return _translate(id);
  }

  Future<String?> _translate(int id) async {
    final message = _find(id);
    final pair = _pair;
    if (message == null || pair == null) return null;
    final source = message.isLeft ? pair.left.code : pair.right.code;
    final target = message.isLeft ? pair.right.code : pair.left.code;
    try {
      final translated = await ref.read(translationServiceProvider).translate(
            text: message.originalText,
            source: source,
            target: target,
          );
      _replace(id, (m) => m.withTranslation(translatedText: translated));
      // Your own messages: also translate back, so you can check what you're
      // sending. Runs after we return, so the auto-copy doesn't wait for it.
      if (!message.isLeft && readBackEnabled(ref)) {
        unawaited(_readBack(id, translated, from: target, to: source));
      }
      return translated;
    } on TranslationException catch (e) {
      _replace(
        id,
        (m) => m.withTranslation(
          translatedText: null,
          failed: !e.limitReached,
          limitReached: e.limitReached,
        ),
      );
      return null;
    }
  }

  Future<void> _readBack(
    int id,
    String translated, {
    required String from,
    required String to,
  }) async {
    try {
      final back = await ref.read(translationServiceProvider).translate(
            text: translated,
            source: from,
            target: to,
          );
      // Only attach if the bubble still shows that same translation.
      _replace(
        id,
        (m) => m.translatedText == translated ? m.withReadBack(back) : m,
      );
    } on TranslationException {
      // Read-back is a nice-to-have: on failure the bubble just goes without.
    }
  }

  Message? _find(int id) {
    for (final m in state) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// No-op if the message was deleted while its translation was in flight.
  void _replace(int id, Message Function(Message) update) {
    state = [for (final m in state) m.id == id ? update(m) : m];
  }

  /// Removes one message; returns its index + the message for Undo.
  (int, Message)? delete(int id) {
    final index = state.indexWhere((m) => m.id == id);
    if (index < 0) return null;
    final removed = state[index];
    state = [...state]..removeAt(index);
    return (index, removed);
  }

  void insert(int index, Message message) {
    final list = [...state];
    list.insert(index.clamp(0, list.length), message);
    state = list;
  }

  /// Removes everything; returns the old list for Undo.
  List<Message> clear() {
    final previous = state;
    state = const [];
    return previous;
  }

  void restore(List<Message> messages) {
    state = [...messages, ...state];
  }
}

final textConversationProvider =
    NotifierProvider<TextConversationNotifier, List<Message>>(
  TextConversationNotifier.new,
);
