import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme.dart';
import 'active_side.dart';
import 'bubble_actions.dart';
import 'conversation_state.dart';
import 'draft_bubble.dart';
import 'language_pair.dart';
import 'message.dart';
import 'message_bubble.dart';
import 'top_bar.dart';

class ConversationPage extends ConsumerStatefulWidget {
  const ConversationPage({super.key});

  /// Test bypass: skip the mic permission check entirely so widget tests
  /// don't hang on the platform-channel call. Set to `true` in test setUp.
  @visibleForTesting
  static bool bypassMicPermissionInTests = false;

  @override
  ConsumerState<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends ConsumerState<ConversationPage> {
  static const _seenSwipeHintKey = 'seen_swipe_hint';

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowSwipeHint();
      _jumpToBottom();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _maybeShowSwipeHint() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_seenSwipeHintKey) ?? false) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tap a language to talk. Swipe sideways to switch sides.'),
        duration: Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
    await prefs.setBool(_seenSwipeHintKey, true);
  }

  Future<bool> _ensureMicPermission() async {
    if (ConversationPage.bypassMicPermissionInTests) return true;
    PermissionStatus status;
    try {
      status = await Permission.microphone.status;
      // Always give the OS a chance to show its native permission prompt first.
      // request() surfaces the system dialog when access hasn't been decided
      // yet, and is a no-op returning the current status once it has. We must
      // never send the user to Settings before this prompt has had its chance.
      if (!status.isGranted) {
        status = await Permission.microphone.request();
      }
    } catch (_) {
      // permission_handler not available (e.g., widget tests) — assume granted.
      return true;
    }

    if (status.isGranted) return true;

    // Only now — after the OS prompt has been shown and the user still hasn't
    // granted access (they previously declined, so iOS won't prompt again) — do
    // we offer a path to Settings.
    if (!mounted) return false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Microphone access needed'),
        content: const Text(
          "Microphone access is off, so ConvoGo can't transcribe speech. "
          "You can turn it on in Settings, then come back and tap a language "
          "chip to start.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    return false;
  }

  /// Confirms the chosen side's language can actually be recognised on this
  /// device before we activate. If the recogniser isn't installed, shows a
  /// hint pointing the user to system settings and returns false, so we don't
  /// light up a side whose mic would silently catch nothing.
  Future<bool> _ensureLocaleAvailable(
    ActiveSide side,
    bool Function() stale,
  ) async {
    // Same test bypass as the mic gate: widget tests can't drive the STT
    // platform channel, so skip the availability probe entirely.
    if (ConversationPage.bypassMicPermissionInTests) return true;

    final installed =
        await ref.read(conversationProvider.notifier).isLocaleInstalled(side);
    if (installed) return true;
    if (stale() || !mounted) return false;

    final pair = ref.read(languagePairProvider).value;
    final language = side == ActiveSide.left ? pair?.left : pair?.right;
    final name = language?.displayName ?? 'This language';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "$name speech recognition isn't installed on this phone — turn it "
          "on in your system settings, then tap a language to start.",
        ),
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return false;
  }

  /// Bumped on every activation request. The permission and locale checks
  /// below are async; if the user taps again meanwhile (rapid switching), the
  /// older request must neither activate nor show its hint — otherwise a stale
  /// "Thai isn't installed" could pop up while English is the active side.
  int _activationRequest = 0;

  Future<void> _activateWithPermission(ActiveSide side) async {
    final request = ++_activationRequest;
    bool stale() => request != _activationRequest || !mounted;
    final granted = await _ensureMicPermission();
    if (!granted || stale()) return;
    final available = await _ensureLocaleAvailable(side, stale);
    if (!available || stale()) return;
    ref.read(conversationProvider.notifier).activate(side);
  }

  /// Tapping a language chip activates its side — unless that side is already
  /// active, in which case it turns it off (back to neutral). Reads as an
  /// on/off toggle on the lit-up chip, and gives the user a deliberate way to
  /// stop the hot mic without waiting out the 60s auto-suspend.
  void _onChipTap(ActiveSide side) {
    if (ref.read(conversationProvider).activeSide == side) {
      _activationRequest++; // cancel any activation still being checked
      ref.read(conversationProvider.notifier).deactivate();
    } else {
      _activateWithPermission(side);
    }
  }

  void _clearConversation() {
    final notifier = ref.read(conversationProvider.notifier);
    final removed = notifier.clearMessages();
    if (removed.isEmpty) return;
    showUndoSnackBar(
      context,
      text: 'Conversation cleared',
      onUndo: () => notifier.restoreMessages(removed),
    );
  }

  void _openBubbleMenu(Message message) {
    final pair = ref.read(languagePairProvider).value;
    if (pair == null) return;
    final original = message.isLeft ? pair.left : pair.right;
    final translation = message.isLeft ? pair.right : pair.left;
    showBubbleMenu(
      context,
      message: message,
      originalLanguage: original.displayName,
      translationLanguage: translation.displayName,
      allowCopy: false,
      onDelete: () {
        final notifier = ref.read(conversationProvider.notifier);
        final removed = notifier.deleteMessage(message.id);
        if (removed == null || !mounted) return;
        final (index, msg) = removed;
        showUndoSnackBar(
          context,
          text: 'Bubble deleted',
          onUndo: () => notifier.insertMessage(index, msg),
        );
      },
    );
  }

  /// Opening the page (e.g. switching back from text mode) builds a fresh
  /// list that would start at the top; land on the latest messages instead.
  /// Twice: a lazy list only knows its true length after laying out the end.
  void _jumpToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
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
    final convo = ref.watch(conversationProvider);
    final notifier = ref.read(conversationProvider.notifier);

    ref.listen(conversationProvider, (previous, next) {
      final prevCount = previous?.messages.length ?? 0;
      final prevDraft = previous?.draftText ?? '';
      // Also when the last bubble changes in place: its translation landing
      // makes it taller, which would otherwise leave it half off-screen.
      final prevLast = previous?.messages.lastOrNull;
      final lastChanged = !identical(prevLast, next.messages.lastOrNull);
      if (next.messages.length > prevCount ||
          next.draftText != prevDraft ||
          lastChanged) {
        _scrollToBottom();
      }
    });

    final pair = ref.watch(languagePairProvider).value;
    final leftCode = pair?.left.chipLabel ?? 'EN';
    final rightCode = pair?.right.chipLabel ?? 'ES';

    final showDraft = convo.activeSide != ActiveSide.neutral;
    final draftIsLeft = convo.activeSide == ActiveSide.left;

    return Scaffold(
      backgroundColor: AppColors.chatBackground,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            // Lower than typical mobile flick velocities to also catch
            // slower mouse drags in Chrome during dev.
            const swipeVelocityThreshold = 200.0;
            final velocity = details.primaryVelocity ?? 0.0;
            // Carousel convention: swipe pushes the current side away,
            // revealing the opposite side. Swipe right → activate left;
            // swipe left → activate right.
            if (velocity > swipeVelocityThreshold) {
              _activateWithPermission(ActiveSide.left);
            } else if (velocity < -swipeVelocityThreshold) {
              _activateWithPermission(ActiveSide.right);
            }
          },
          child: Column(
            children: [
              ConvoTopBar(
                canClear: convo.messages.isNotEmpty,
                onClear: _clearConversation,
              ),
              LanguageChipsRow(
                leftCode: leftCode,
                rightCode: rightCode,
                activeSide: convo.activeSide,
                onLeftTap: () => _onChipTap(ActiveSide.left),
                onRightTap: () => _onChipTap(ActiveSide.right),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    // Tap anywhere in the chat area switches sides (or
                    // activates *your* side — the right — from neutral).
                    // Failed-translation bubbles still win for retry because
                    // their child GestureDetector handles the tap first.
                    final next = switch (convo.activeSide) {
                      ActiveSide.neutral => ActiveSide.right,
                      ActiveSide.left => ActiveSide.right,
                      ActiveSide.right => ActiveSide.left,
                    };
                    _activateWithPermission(next);
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: convo.messages.length + (showDraft ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < convo.messages.length) {
                        final message = convo.messages[index];
                        final isActiveSide =
                            (message.isLeft && convo.activeSide == ActiveSide.left) ||
                                (!message.isLeft && convo.activeSide == ActiveSide.right);
                        return MessageBubble(
                          message: message,
                          isActiveSide: isActiveSide,
                          onRetry: () => notifier.retryTranslation(message.id),
                          onLongPress: () => _openBubbleMenu(message),
                        );
                      }
                      return DraftBubble(
                        text: convo.draftText,
                        isLeft: draftIsLeft,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
