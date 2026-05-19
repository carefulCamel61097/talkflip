import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'active_side.dart';
import 'message.dart';
import 'stt_service.dart';

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

  @override
  ConversationState build() {
    _stt = SttService();
    ref.onDispose(_stt.dispose);
    return ConversationState.initial;
  }

  // Hardcoded for M3; M6 will source these from persisted language settings.
  String _localeFor(ActiveSide side) {
    return side == ActiveSide.left ? 'en_US' : 'es_ES';
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
    final committed = Message(
      originalText: draft,
      translatedText: '...',
      isLeft: isLeft,
    );

    state = state.copyWith(
      messages: [...state.messages, committed],
      draftText: '',
    );
  }
}

final conversationProvider =
    NotifierProvider<ConversationNotifier, ConversationState>(
  ConversationNotifier.new,
);
