import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'active_side.dart';
import 'message.dart';
import 'stt_service.dart';
import 'translation_service.dart';

class ConversationState {
  final ActiveSide activeSide;
  final List<Message> messages;
  final String draftText;

  const ConversationState({
    required this.activeSide,
    required this.messages,
    required this.draftText,
  });

  static const initial = ConversationState(
    activeSide: ActiveSide.neutral,
    messages: [],
    draftText: '',
  );

  ConversationState copyWith({
    ActiveSide? activeSide,
    List<Message>? messages,
    String? draftText,
  }) {
    return ConversationState(
      activeSide: activeSide ?? this.activeSide,
      messages: messages ?? this.messages,
      draftText: draftText ?? this.draftText,
    );
  }
}

class ConversationNotifier extends Notifier<ConversationState> {
  late final SttService _stt;
  late final TranslationService _translation;
  int _nextMessageId = 0;

  @override
  ConversationState build() {
    _stt = SttService();
    _translation = ref.read(translationServiceProvider);
    ref.onDispose(_stt.dispose);
    return ConversationState.initial;
  }

  // Hardcoded for M3/M4; M6 will source these from persisted language settings.
  String _localeFor(ActiveSide side) {
    return side == ActiveSide.left ? 'en_US' : 'es_ES';
  }

  String _langCodeFor(ActiveSide side) {
    return side == ActiveSide.left ? 'en' : 'es';
  }

  Future<void> activate(ActiveSide side) async {
    if (side == ActiveSide.neutral) return;
    if (side == state.activeSide) return;

    if (state.draftText.trim().isNotEmpty) {
      _commitDraft();
    }

    await _stt.stopListening();

    state = state.copyWith(activeSide: side, draftText: '');

    await _stt.startListening(
      locale: _localeFor(side),
      onResult: _handleSttResult,
    );
  }

  void _handleSttResult(String text, bool isFinal) {
    state = state.copyWith(draftText: text);
    if (isFinal) {
      _commitDraft();
    }
  }

  void _commitDraft() {
    final draft = state.draftText.trim();
    if (draft.isEmpty) return;

    final isLeft = state.activeSide == ActiveSide.left;
    final source = _langCodeFor(state.activeSide);
    final target = isLeft ? 'es' : 'en';

    final id = _nextMessageId++;
    final pending = Message(
      id: id,
      originalText: draft,
      translatedText: null,
      isLeft: isLeft,
    );

    state = state.copyWith(
      messages: [...state.messages, pending],
      draftText: '',
    );

    // Fire-and-forget translation. Result updates the message in place by ID.
    _translateMessage(id: id, text: draft, source: source, target: target);
  }

  Future<void> _translateMessage({
    required int id,
    required String text,
    required String source,
    required String target,
  }) async {
    try {
      final translated = await _translation.translate(
        text: text,
        source: source,
        target: target,
      );
      _updateMessage(id: id, translatedText: translated, failed: false);
    } on TranslationException {
      _updateMessage(id: id, translatedText: null, failed: true);
    }
  }

  void _updateMessage({
    required int id,
    required String? translatedText,
    required bool failed,
  }) {
    final updated = state.messages.map((m) {
      if (m.id != id) return m;
      return Message(
        id: m.id,
        originalText: m.originalText,
        translatedText: translatedText,
        isLeft: m.isLeft,
        translationFailed: failed,
      );
    }).toList();
    state = state.copyWith(messages: updated);
  }

  Future<void> retryTranslation(int id) async {
    Message? message;
    for (final m in state.messages) {
      if (m.id == id) {
        message = m;
        break;
      }
    }
    if (message == null) return;

    _updateMessage(id: id, translatedText: null, failed: false);

    final source = message.isLeft ? 'en' : 'es';
    final target = message.isLeft ? 'es' : 'en';
    await _translateMessage(
      id: id,
      text: message.originalText,
      source: source,
      target: target,
    );
  }
}

final conversationProvider =
    NotifierProvider<ConversationNotifier, ConversationState>(
  ConversationNotifier.new,
);
