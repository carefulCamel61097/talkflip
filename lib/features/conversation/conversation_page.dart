import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme.dart';
import '../settings/settings_page.dart';
import 'active_side.dart';
import 'connectivity_provider.dart';
import 'conversation_state.dart';
import 'draft_bubble.dart';
import 'language_pair.dart';
import 'message_bubble.dart';

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
    try {
      final status = await Permission.microphone.status;
      if (status.isGranted) return true;
      if (status.isDenied) {
        final newStatus = await Permission.microphone.request();
        if (newStatus.isGranted) return true;
      }
    } catch (_) {
      // permission_handler not available (e.g., widget tests) — assume granted.
      return true;
    }

    if (!mounted) return false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Microphone access needed'),
        content: const Text(
          "Microphone access is blocked, so ConvoGo can't transcribe speech. "
          "Open your device settings to enable it, then come back and tap a "
          "language chip to start.",
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

  Future<void> _activateWithPermission(ActiveSide side) async {
    final granted = await _ensureMicPermission();
    if (granted && mounted) {
      ref.read(conversationProvider.notifier).activate(side);
    }
  }

  /// Tapping a language chip activates its side — unless that side is already
  /// active, in which case it turns it off (back to neutral). Reads as an
  /// on/off toggle on the lit-up chip, and gives the user a deliberate way to
  /// stop the hot mic without waiting out the 60s auto-suspend.
  void _onChipTap(ActiveSide side) {
    if (ref.read(conversationProvider).activeSide == side) {
      ref.read(conversationProvider.notifier).deactivate();
    } else {
      _activateWithPermission(side);
    }
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
      if (next.messages.length > prevCount || next.draftText != prevDraft) {
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
              const _TopBar(),
              _LanguageChipsRow(
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
                    // activates left from neutral). Failed-translation
                    // bubbles still win for retry because their child
                    // GestureDetector handles the tap first.
                    final next = switch (convo.activeSide) {
                      ActiveSide.neutral => ActiveSide.left,
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

class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityProvider).value ?? true;
    return SizedBox(
      height: 48,
      child: Stack(
        children: [
          Center(
            child: IconButton(
              icon: const Icon(
                Icons.settings_outlined,
                size: 22,
                color: AppColors.settingsCog,
              ),
              tooltip: 'Settings',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              },
            ),
          ),
          if (!isOnline)
            const Positioned(
              right: 16,
              top: 16,
              child: _OfflineDot(),
            ),
        ],
      ),
    );
  }
}

class _OfflineDot extends StatelessWidget {
  const _OfflineDot();

  @override
  Widget build(BuildContext context) {
    return const Tooltip(
      message: 'Offline — translation unavailable',
      child: SizedBox(
        width: 10,
        height: 10,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xFFB0B0B0),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _LanguageChipsRow extends StatelessWidget {
  final String leftCode;
  final String rightCode;
  final ActiveSide activeSide;
  final VoidCallback onLeftTap;
  final VoidCallback onRightTap;

  const _LanguageChipsRow({
    required this.leftCode,
    required this.rightCode,
    required this.activeSide,
    required this.onLeftTap,
    required this.onRightTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _LanguageChip(
            code: leftCode,
            isActive: activeSide == ActiveSide.left,
            onTap: onLeftTap,
          ),
          _LanguageChip(
            code: rightCode,
            isActive: activeSide == ActiveSide.right,
            onTap: onRightTap,
          ),
        ],
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  final String code;
  final bool isActive;
  final VoidCallback onTap;

  const _LanguageChip({
    required this.code,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: isActive
                ? const DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? AppColors.activeChipFill : AppColors.inactiveChipFill,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.accent, width: 1.5),
            ),
            child: Text(
              code,
              style: AppTextStyles.languageChip.copyWith(
                color: isActive ? AppColors.activeChipText : AppColors.inactiveChipText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
