import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../conversation/active_side.dart';
import '../conversation/bubble_actions.dart';
import '../conversation/language_pair.dart';
import '../conversation/message.dart';
import '../conversation/message_bubble.dart';
import '../conversation/top_bar.dart';
import '../settings/read_back_setting.dart';
import 'text_conversation_state.dart';

/// Text mode: for chatting in another app (WhatsApp, LINE, …).
///
/// Their side (left) has a one-tap Paste button — you never type their
/// language. Your side (right) is a text field; on send the translation is
/// copied to the clipboard, ready to paste into the chat app. Tapping the
/// original or the translation inside a bubble copies exactly that part.
class TextConversationPage extends ConsumerStatefulWidget {
  const TextConversationPage({super.key});

  @override
  ConsumerState<TextConversationPage> createState() =>
      _TextConversationPageState();
}

class _TextConversationPageState extends ConsumerState<TextConversationPage> {
  final _input = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Rebuild so the Paste button hides/shows as the field fills/empties.
    _input.addListener(() => setState(() {}));
    // Land on the latest messages when the page (re)opens, e.g. after
    // switching back from voice mode. Twice: a lazy list only knows its true
    // length after laying out the end.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      });
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  LanguagePair? get _pair => ref.read(languagePairProvider).value;

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!mounted) return;
    if (text.isEmpty) {
      showToast(context, 'Nothing to paste. Copy their message in your chat app first.');
      return;
    }
    await ref.read(textConversationProvider.notifier).addTheirs(text);
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    final translated =
        await ref.read(textConversationProvider.notifier).sendMine(text);
    _copyYourTranslation(translated);
  }

  Future<void> _retry(Message message) async {
    final translated =
        await ref.read(textConversationProvider.notifier).retry(message.id);
    // A retried message of yours gets the same auto-copy as a fresh send.
    if (!message.isLeft) _copyYourTranslation(translated);
  }

  void _copyYourTranslation(String? translated) {
    final pair = _pair;
    if (translated == null || pair == null || !mounted) return;
    copyWithToast(
      context,
      translated,
      '${pair.theirs.displayName} copied. Paste it in your chat.',
    );
  }

  void _clear() {
    final notifier = ref.read(textConversationProvider.notifier);
    final removed = notifier.clear();
    if (removed.isEmpty) return;
    showUndoSnackBar(
      context,
      text: 'Conversation cleared',
      onUndo: () => notifier.restore(removed),
    );
  }

  void _openMenu(Message message, LanguagePair pair) {
    showBubbleMenu(
      context,
      message: message,
      originalLanguage: (message.isLeft ? pair.left : pair.right).displayName,
      translationLanguage: (message.isLeft ? pair.right : pair.left).displayName,
      onDelete: () {
        final notifier = ref.read(textConversationProvider.notifier);
        final removed = notifier.delete(message.id);
        if (removed == null || !mounted) return;
        final (index, msg) = removed;
        showUndoSnackBar(
          context,
          text: 'Bubble deleted',
          onUndo: () => notifier.insert(index, msg),
        );
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(textConversationProvider);
    final pair = ref.watch(languagePairProvider).value;
    final showReadBack =
        ref.watch(readBackProvider).value ?? ReadBackNotifier.defaultValue;

    ref.listen(textConversationProvider, (previous, next) {
      // New bubble, or the last bubble changed in place (its translation
      // landed and made it taller).
      if (next.length > (previous?.length ?? 0) ||
          !identical(previous?.lastOrNull, next.lastOrNull)) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.chatBackground,
      body: SafeArea(
        child: Column(
          children: [
            ConvoTopBar(canClear: messages.isNotEmpty, onClear: _clear),
            LanguageChipsRow(
              leftCode: pair?.left.chipLabel ?? '',
              rightCode: pair?.right.chipLabel ?? '',
              activeSide: ActiveSide.neutral,
            ),
            Expanded(
              child: messages.isEmpty || pair == null
                  ? _EmptyHint(pair: pair)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final m = messages[index];
                        final originalLang = m.isLeft ? pair.left : pair.right;
                        final translationLang = m.isLeft ? pair.right : pair.left;
                        return MessageBubble(
                          message: m,
                          onRetry: () => _retry(m),
                          onCopyOriginal: () => copyWithToast(
                            context,
                            m.originalText,
                            '${originalLang.displayName} copied',
                          ),
                          onCopyTranslation: () => copyWithToast(
                            context,
                            m.translatedText!,
                            '${translationLang.displayName} copied',
                          ),
                          onLongPress: () => _openMenu(m, pair),
                          showReadBack: showReadBack,
                        );
                      },
                    ),
            ),
            _Composer(
              controller: _input,
              theirLanguage: pair?.theirs.displayName ?? '',
              myLanguage: pair?.mine.displayName ?? '',
              onPaste: _paste,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown before the first message, so the flow is obvious on first use.
class _EmptyHint extends StatelessWidget {
  final LanguagePair? pair;

  const _EmptyHint({required this.pair});

  @override
  Widget build(BuildContext context) {
    final theirs = pair?.theirs.displayName ?? 'their language';
    final mine = pair?.mine.displayName ?? 'your language';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          'Copy a $theirs message in your chat app, then tap Paste.\n\n'
          'Write your reply in $mine below. The $theirs translation is '
          'copied for you, ready to paste back.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: AppColors.subtleText, height: 1.4),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final String theirLanguage;
  final String myLanguage;
  final VoidCallback onPaste;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.theirLanguage,
    required this.myLanguage,
    required this.onPaste,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final typing = controller.text.trim().isNotEmpty;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7F7F7),
        border: Border(top: BorderSide(color: Color(0xFFE2E2E2))),
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Hidden while typing to save space above the keyboard.
          if (!typing) ...[
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton.icon(
                onPressed: onPaste,
                icon: const Icon(Icons.content_paste, size: 18),
                label: Text('Paste $theirLanguage message'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.accent, width: 1.5),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Write in $myLanguage…',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: AppColors.accent),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                onPressed: typing ? onSend : null,
                tooltip: 'Translate and copy',
                icon: const Icon(Icons.send, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.35),
                  disabledForegroundColor: Colors.white,
                  fixedSize: const Size(44, 44),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
