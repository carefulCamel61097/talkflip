import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import 'message.dart';

/// Shared bubble/conversation actions for both modes: copying, the long-press
/// menu, and Undo snackbars.

/// Copies [text] and confirms with a short snackbar ("Thai copied").
Future<void> copyWithToast(
  BuildContext context,
  String text,
  String confirmation,
) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  showToast(context, confirmation);
}

void showToast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

/// A snackbar with an Undo action. Uses `persist: false` because Flutter keeps
/// snackbars that have an action on screen indefinitely by default.
void showUndoSnackBar(
  BuildContext context, {
  required String text,
  required VoidCallback onUndo,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        action: SnackBarAction(label: 'Undo', onPressed: onUndo),
        duration: const Duration(seconds: 4),
        persist: false,
        behavior: SnackBarBehavior.floating,
      ),
    );
}

/// Long-press menu for a bubble: copy translation, copy original, delete.
/// [originalLanguage] / [translationLanguage] are display names ("Thai").
/// Voice mode passes [allowCopy] false: both languages are already on screen
/// for the two people present, so there's nothing to copy elsewhere.
Future<void> showBubbleMenu(
  BuildContext context, {
  required Message message,
  required String originalLanguage,
  required String translationLanguage,
  required VoidCallback onDelete,
  bool allowCopy = true,
}) async {
  HapticFeedback.selectionClick();
  // Drop focus first: when the sheet closes, Flutter restores focus to
  // whatever had it before — a text field left focused from earlier typing
  // would pop the keyboard back up after "Delete bubble".
  FocusManager.instance.primaryFocus?.unfocus();
  final translated = message.translatedText;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (allowCopy && translated != null)
            ListTile(
              leading: const Icon(Icons.copy, color: AppColors.accent),
              title: Text('Copy $translationLanguage'),
              subtitle: Text(
                translated,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                copyWithToast(
                  context,
                  translated,
                  '$translationLanguage copied',
                );
              },
            ),
          if (allowCopy)
            ListTile(
              leading: const Icon(Icons.copy_outlined, color: AppColors.accent),
              title: Text('Copy $originalLanguage'),
              subtitle: Text(
                message.originalText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                copyWithToast(
                  context,
                  message.originalText,
                  '$originalLanguage copied',
                );
              },
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Color(0xFFC0392B)),
            title: const Text(
              'Delete bubble',
              style: TextStyle(color: Color(0xFFC0392B)),
            ),
            onTap: () {
              Navigator.pop(sheetContext);
              onDelete();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
