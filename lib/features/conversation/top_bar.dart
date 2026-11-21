import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_mode.dart';
import '../../core/theme.dart';
import '../settings/settings_page.dart';
import 'active_side.dart';
import 'bubble_actions.dart';
import 'connectivity_provider.dart';
import 'conversation_state.dart';
import 'stt_engine.dart';

/// Top bar shared by voice and text mode:
/// voice/text toggle (left) · settings cog (centre) · clear conversation (right).
/// Status dots (offline / basic speech recognition) sit just beside the cog.
class ConvoTopBar extends ConsumerWidget {
  final VoidCallback onClear;
  final bool canClear;

  const ConvoTopBar({super.key, required this.onClear, required this.canClear});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityProvider).value ?? true;
    final mode = ref.watch(appModeProvider).value ?? AppMode.voice;
    // Only meaningful while online and in voice mode: when offline the offline
    // dot already says "degraded", so the two indicators never show at once.
    final onFallbackStt =
        mode == AppMode.voice &&
        isOnline &&
        ref.watch(sttModeProvider) == SttMode.fallback;

    return SizedBox(
      height: 48,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: _ModeToggle(
                mode: mode,
                onChanged: (next) async {
                  if (next == mode) return;
                  // Text mode has no mic: make sure it's off before leaving
                  // voice mode (the voice notifier outlives its page).
                  if (next == AppMode.text) {
                    await ref.read(conversationProvider.notifier).deactivate();
                  }
                  await ref.read(appModeProvider.notifier).setMode(next);
                },
              ),
            ),
          ),
          Center(
            child: IconButton(
              icon: const Icon(
                Icons.settings_outlined,
                size: 22,
                color: AppColors.settingsCog,
              ),
              tooltip: 'Settings',
              onPressed: () {
                // Drop focus first: on return Flutter restores focus to what
                // had it before, and a text-mode field left focused from
                // earlier typing would pop the keyboard up.
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              },
            ),
          ),
          if (!isOnline || onFallbackStt)
            Center(
              child: Transform.translate(
                offset: const Offset(24, -10),
                // Tappable, so the dot never reads as a mystery "notification"
                // badge on the cog: one tap says what it means.
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showToast(
                    context,
                    !isOnline
                        ? "You're offline. Translation needs an internet connection."
                        : "Cloud speech recognition isn't reachable right now, so "
                              "your phone's built-in recognition is used. It retries "
                              'automatically.',
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: !isOnline
                        ? const _OfflineDot()
                        : const _FallbackSttDot(),
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _ClearButton(enabled: canClear, onTap: onClear),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grey pill mirroring [_ModeToggle] (same size, same distance from the edge),
/// so the centred cog also *looks* centred. The "Clear" label makes the action
/// unambiguous; the icon alone read like a generic list/menu glyph.
class _ClearButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _ClearButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? AppColors.settingsCog
        : AppColors.settingsCog.withValues(alpha: 0.4);
    return Tooltip(
      message: 'Clear conversation',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Container(
          width: _ModeToggle.width,
          height: _ModeToggle.height,
          decoration: BoxDecoration(
            color: const Color(0xFFDCDCDC),
            borderRadius: BorderRadius.circular(999),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          // Scales down rather than overflowing with large system font sizes.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete_outline, size: 17, color: color),
                const SizedBox(width: 3),
                Text(
                  'Clear',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small two-icon pill: mic (voice) | keyboard (text). Both icons are always
/// visible, so the other mode is discoverable at a glance.
class _ModeToggle extends StatelessWidget {
  final AppMode mode;
  final ValueChanged<AppMode> onChanged;

  const _ModeToggle({required this.mode, required this.onChanged});

  // Outer size (2 × 38px segments + 2px padding each side), shared with
  // _ClearButton so the two sides of the bar mirror each other.
  static const double width = 80;
  static const double height = 34;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFFDCDCDC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(AppMode.voice, Icons.mic_none, 'Voice mode'),
          _segment(AppMode.text, Icons.keyboard_outlined, 'Text mode'),
        ],
      ),
    );
  }

  Widget _segment(AppMode value, IconData icon, String tooltip) {
    final selected = mode == value;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 38,
          height: 30,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 18,
            color: selected ? AppColors.accent : AppColors.settingsCog,
          ),
        ),
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

/// Shown (in place of the offline dot) when the cloud recogniser is unreachable
/// and we've fallen back to the on-device engine. Same understated dot as the
/// offline indicator but a muted amber, signalling "working, just degraded" —
/// not an alarm. The tooltip explains it on long-press/hover.
class _FallbackSttDot extends StatelessWidget {
  const _FallbackSttDot();

  @override
  Widget build(BuildContext context) {
    return const Tooltip(
      message: 'Using basic speech recognition',
      child: SizedBox(
        width: 10,
        height: 10,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xFFD9A05B),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// The two language chips. Left = the other person (THEM), right = you (YOU).
/// In voice mode the chips activate their side; in text mode they're labels
/// (pass null taps).
class LanguageChipsRow extends StatelessWidget {
  final String leftCode;
  final String rightCode;
  final ActiveSide activeSide;
  final VoidCallback? onLeftTap;
  final VoidCallback? onRightTap;

  const LanguageChipsRow({
    super.key,
    required this.leftCode,
    required this.rightCode,
    required this.activeSide,
    this.onLeftTap,
    this.onRightTap,
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
            label: 'THEM',
            isActive: activeSide == ActiveSide.left,
            onTap: onLeftTap,
          ),
          _LanguageChip(
            code: rightCode,
            label: 'YOU',
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
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _LanguageChip({
    required this.code,
    required this.label,
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
              color: isActive
                  ? AppColors.activeChipFill
                  : AppColors.inactiveChipFill,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.accent, width: 1.5),
            ),
            child: Text(
              code,
              style: AppTextStyles.languageChip.copyWith(
                color: isActive
                    ? AppColors.activeChipText
                    : AppColors.inactiveChipText,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: AppColors.subtleText,
            ),
          ),
        ],
      ),
    );
  }
}
