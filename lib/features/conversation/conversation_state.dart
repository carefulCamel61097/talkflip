import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supported_languages.dart';
import 'active_side.dart';
import 'language_pair.dart';
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

  /// Incremented every time we (re)start listening for a new side. STT result
  /// callbacks capture the epoch they were started under; a callback whose
  /// epoch no longer matches is a straggler from a session we've already
  /// switched away from, and is ignored so its text can't land on the new
  /// side. See the mid-speech-switch fix.
  int _listenEpoch = 0;

  @override
  ConversationState build() {
    _stt = SttService();
    _translation = ref.read(translationServiceProvider);
    ref.onDispose(_stt.dispose);
    return ConversationState.initial;
  }

  LanguagePair? get _pair => ref.read(languagePairProvider).value;

  Language? _languageFor(ActiveSide side) {
    final pair = _pair;
    if (pair == null) return null;
    return side == ActiveSide.left ? pair.left : pair.right;
  }

  Future<void> activate(ActiveSide side) async {
    if (side == ActiveSide.neutral) return;
    if (side == state.activeSide) return;

    // Capture the in-flight draft and the side it was spoken on *before* we
    // touch anything, so it commits to the original speaker's side regardless
    // of what we're switching to.
    final previousSide = state.activeSide;
    final pendingDraft = state.draftText;

    // Stop first: SttService detaches its callback, so the dying session's
    // final result can no longer be delivered to anyone.
    await _stt.stopListening();

    if (previousSide != ActiveSide.neutral) {
      _commitText(pendingDraft, previousSide);
    }

    // Retire the old session's epoch; any straggler that still slips through
    // will fail the epoch check in _handleSttResult.
    final epoch = ++_listenEpoch;
    state = state.copyWith(activeSide: side, draftText: '');

    final language = _languageFor(side);
    if (language == null) return;

    await _stt.startListening(
      locale: language.sttLocale,
      onResult: (text, isFinal) => _handleSttResult(epoch, side, text, isFinal),
      onSuspended: _handleSttSuspended,
    );
  }

  /// Turns the active side off, returning to neutral and stopping the mic.
  /// Mirrors the side-switch: the in-flight draft commits to the side it was
  /// spoken on, so turning off mid-sentence doesn't silently eat words.
  /// Reached by tapping the already-active language chip.
  Future<void> deactivate() async {
    if (state.activeSide == ActiveSide.neutral) return;

    final previousSide = state.activeSide;
    final pendingDraft = state.draftText;

    await _stt.stopListening();

    _commitText(pendingDraft, previousSide);

    // Retire the old session's epoch so any straggler callback is dropped.
    _listenEpoch++;
    state = state.copyWith(activeSide: ActiveSide.neutral, draftText: '');
  }

  void _handleSttResult(int epoch, ActiveSide side, String text, bool isFinal) {
    // Straggler from a session we've already switched away from — ignore it so
    // its text can't leak onto the now-active side.
    if (epoch != _listenEpoch) return;
    state = state.copyWith(draftText: text);
    if (isFinal) {
      _commitText(text, side);
    }
  }

  void _handleSttSuspended() {
    state = state.copyWith(activeSide: ActiveSide.neutral, draftText: '');
  }

  /// Commits [rawText] as a message attributed to [side] — the side the words
  /// were actually spoken on, which is not necessarily the currently active
  /// side (a switch mid-utterance commits to the side that was active when the
  /// speech happened).
  void _commitText(String rawText, ActiveSide side) {
    final draft = rawText.trim();
    if (draft.isEmpty) return;

    final pair = _pair;
    if (pair == null) return;

    final isLeft = side == ActiveSide.left;
    final source = isLeft ? pair.left.code : pair.right.code;
    final target = isLeft ? pair.right.code : pair.left.code;

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

  void clearMessages() {
    state = state.copyWith(messages: const [], draftText: '');
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

    final pair = _pair;
    if (pair == null) return;

    _updateMessage(id: id, translatedText: null, failed: false);

    final source = message.isLeft ? pair.left.code : pair.right.code;
    final target = message.isLeft ? pair.right.code : pair.left.code;
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
