import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:talkflip/main.dart';
import 'package:talkflip/features/conversation/conversation_page.dart';
import 'package:talkflip/features/conversation/draft_bubble.dart';
import 'package:talkflip/features/conversation/language_picker_page.dart';
import 'package:talkflip/features/conversation/message_bubble.dart';
import 'package:talkflip/features/conversation/stt_engine.dart';
import 'package:talkflip/features/conversation/translation_service.dart';
import 'package:talkflip/features/settings/read_back_setting.dart';
import 'package:talkflip/features/settings/settings_page.dart';
import 'package:talkflip/features/text_mode/text_conversation_page.dart';

class _StubTranslationService extends TranslationService {
  _StubTranslationService() : super(dio: Dio());

  @override
  Future<String> translate({
    required String text,
    required String source,
    required String target,
  }) async {
    return 'stub: $text';
  }
}

/// A no-op [SttEngine] for widget tests. The real engines reach for the network
/// (cloud WebSocket) and the native speech platform channel, neither of which
/// exists under `flutter test` — so without this the activation tests race a
/// real connect attempt and flake. The fake just records that it was asked to
/// listen; the UI logic under test (activate → draft shows, deactivate → draft
/// hides) depends only on the conversation state, not on any recogniser output.
class _FakeSttEngine implements SttEngine {
  @override
  Future<bool> isLocaleAvailable(String locale) async => true;

  @override
  Future<void> startListening({
    required String locale,
    required void Function(String text, bool isFinal) onResult,
    required void Function() onSuspended,
    required void Function() onError,
  }) async {}

  @override
  Future<void> stopListening() async {}

  @override
  void dispose() {}
}

Widget _app() {
  return ProviderScope(
    overrides: [
      translationServiceProvider.overrideWith((ref) => _StubTranslationService()),
      sttEngineProvider.overrideWithValue(_FakeSttEngine()),
    ],
    child: const ConvoGoApp(),
  );
}

void main() {
  setUp(() {
    // Default: a language pair is already stored, so tests skip the picker
    // and land on the conversation page. seen_swipe_hint is pre-set so the
    // first-launch snackbar doesn't appear and interfere with assertions.
    // 'language_pair_left' holds *your* language (legacy key name), shown on
    // the RIGHT: EN (you) is the right chip, ES (them) the left chip.
    SharedPreferences.setMockInitialValues({
      'language_pair_left': 'en',
      'language_pair_right': 'es',
      'seen_swipe_hint': true,
    });
    // Skip the mic permission check — the platform channel for
    // permission_handler hangs in tests, blocking pumpAndSettle.
    ConversationPage.bypassMicPermissionInTests = true;
  });

  tearDown(() {
    ConversationPage.bypassMicPermissionInTests = false;
  });

  testWidgets('First launch (no pair stored) shows the language picker', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byType(LanguagePickerPage), findsOneWidget);
  });

  testWidgets('App boots and shows both language chips', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('EN'), findsOneWidget);
    expect(find.text('ES'), findsOneWidget);
  });

  testWidgets('Neutral state shows no draft bubble', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byType(DraftBubble), findsNothing);
  });

  testWidgets('Your language (EN) is the right chip, theirs (ES) the left', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    final en = tester.getCenter(find.text('EN')).dx;
    final es = tester.getCenter(find.text('ES')).dx;
    expect(en, greaterThan(es));
    expect(find.text('YOU'), findsOneWidget);
    expect(find.text('THEM'), findsOneWidget);
  });

  testWidgets('Tapping EN chip (you) activates the right side', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    final draft = tester.widget<DraftBubble>(find.byType(DraftBubble));
    expect(draft.isLeft, isFalse);
  });

  testWidgets('Tapping ES chip (them) activates the left side', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('ES'));
    await tester.pumpAndSettle();
    final draft = tester.widget<DraftBubble>(find.byType(DraftBubble));
    expect(draft.isLeft, isTrue);
  });

  testWidgets('Tapping the chat from neutral activates your side (right)', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListView));
    await tester.pumpAndSettle();
    final draft = tester.widget<DraftBubble>(find.byType(DraftBubble));
    expect(draft.isLeft, isFalse);
  });

  testWidgets('Tapping the already-active chip turns the side off (neutral)', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    // First tap activates the left side.
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    expect(find.byType(DraftBubble), findsOneWidget);
    // Second tap on the same chip deactivates back to neutral.
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    expect(find.byType(DraftBubble), findsNothing);
  });

  testWidgets('Swiping right activates the left side (carousel convention)', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.fling(find.byType(Scaffold), const Offset(500, 0), 1000);
    await tester.pumpAndSettle();
    final draft = tester.widget<DraftBubble>(find.byType(DraftBubble));
    expect(draft.isLeft, isTrue);
  });

  testWidgets('Swiping left activates the right side (carousel convention)', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.fling(find.byType(Scaffold), const Offset(-500, 0), 1000);
    await tester.pumpAndSettle();
    final draft = tester.widget<DraftBubble>(find.byType(DraftBubble));
    expect(draft.isLeft, isFalse);
  });

  testWidgets('Tapping settings cog opens the settings page', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.text('Change languages'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
  });

  testWidgets('Tapping "Change languages" opens the picker with current pair', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change languages'));
    await tester.pumpAndSettle();
    expect(find.byType(LanguagePickerPage), findsOneWidget);
    // The current pair (English & Spanish from setUp) should be pre-selected.
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Spanish'), findsOneWidget);
  });

  testWidgets('Language search: filter and pick a language', (tester) async {
    // No stored pair → first-launch picker.
    SharedPreferences.setMockInitialValues({'seen_swipe_hint': true});
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byType(LanguagePickerPage), findsOneWidget);

    // Both selectors start empty.
    expect(find.text('Select…'), findsNWidgets(2));

    // Open the search page from the first selector, filter to Thai, pick it.
    await tester.tap(find.text('Select…').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'thai');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thai'));
    await tester.pumpAndSettle();

    // Selection is reflected back on the picker.
    expect(find.text('Thai'), findsOneWidget);
    expect(find.text('Select…'), findsOneWidget);
  });

  group('Text mode', () {
    late List<String> copied;
    String? clipboardText;

    setUp(() {
      copied = [];
      clipboardText = null;
    });

    void mockClipboard(WidgetTester tester) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
            return null;
          }
          if (call.method == 'Clipboard.getData') {
            return clipboardText == null ? null : {'text': clipboardText};
          }
          return null;
        },
      );
    }

    Future<void> openTextMode(WidgetTester tester) async {
      mockClipboard(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Text mode'));
      await tester.pumpAndSettle();
    }

    Future<void> pasteTheirs(WidgetTester tester, String text) async {
      clipboardText = text;
      await tester.tap(find.text('Paste Spanish message'));
      await tester.pumpAndSettle();
    }

    testWidgets('Mode toggle switches to text mode and back', (tester) async {
      await openTextMode(tester);
      expect(find.byType(TextConversationPage), findsOneWidget);
      expect(find.text('Paste Spanish message'), findsOneWidget);
      await tester.tap(find.byTooltip('Voice mode'));
      await tester.pumpAndSettle();
      expect(find.byType(ConversationPage), findsOneWidget);
    });

    testWidgets('Saved text mode reopens in text mode', (tester) async {
      SharedPreferences.setMockInitialValues({
        'language_pair_left': 'en',
        'language_pair_right': 'es',
        'seen_swipe_hint': true,
        'app_mode': 'text',
      });
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.byType(TextConversationPage), findsOneWidget);
    });

    testWidgets('Sending your message translates it and copies the translation', (tester) async {
      await openTextMode(tester);
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      // The Paste button hides while typing.
      expect(find.text('Paste Spanish message'), findsNothing);
      await tester.tap(find.byTooltip('Translate and copy'));
      await tester.pumpAndSettle();
      expect(find.text('hello'), findsOneWidget);
      expect(find.text('stub: hello'), findsOneWidget);
      expect(copied, ['stub: hello']);
      expect(find.text('Spanish copied. Paste it in your chat.'), findsOneWidget);
      final bubble = tester.widget<MessageBubble>(find.byType(MessageBubble));
      expect(bubble.message.isLeft, isFalse);
    });

    testWidgets('Paste adds their message on the left, translated', (tester) async {
      await openTextMode(tester);
      await pasteTheirs(tester, 'hola');
      expect(find.text('stub: hola'), findsOneWidget);
      final bubble = tester.widget<MessageBubble>(find.byType(MessageBubble));
      expect(bubble.message.isLeft, isTrue);
    });

    testWidgets('Paste with an empty clipboard explains what to do', (tester) async {
      await openTextMode(tester);
      await tester.tap(find.text('Paste Spanish message'));
      await tester.pump();
      expect(find.byType(MessageBubble), findsNothing);
      expect(find.textContaining('Nothing to paste'), findsOneWidget);
    });

    testWidgets('Tapping the original or the translation copies just that part', (tester) async {
      await openTextMode(tester);
      await pasteTheirs(tester, 'hola');
      await tester.tap(find.text('hola'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('stub: hola'));
      await tester.pumpAndSettle();
      expect(copied, ['hola', 'stub: hola']);
    });

    testWidgets('Long-press then Delete removes a bubble, Undo brings it back', (tester) async {
      await openTextMode(tester);
      await pasteTheirs(tester, 'hola');
      await tester.longPress(find.text('stub: hola'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete bubble'));
      await tester.pumpAndSettle();
      expect(find.byType(MessageBubble), findsNothing);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.byType(MessageBubble), findsOneWidget);
    });

    testWidgets('Clear button empties the conversation, Undo restores it', (tester) async {
      await openTextMode(tester);
      await pasteTheirs(tester, 'hola');
      await tester.tap(find.byTooltip('Clear conversation'));
      await tester.pumpAndSettle();
      expect(find.byType(MessageBubble), findsNothing);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.byType(MessageBubble), findsOneWidget);
    });
  });

  group('Saved conversations + read-back', () {
    void mockClipboard(WidgetTester tester) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => null,
      );
    }

    Future<void> sendInTextMode(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump();
      await tester.tap(find.byTooltip('Translate and copy'));
      await tester.pumpAndSettle();
    }

    Map<String, Object> prefsWith(Map<String, Object> extra) => {
          'language_pair_left': 'en',
          'language_pair_right': 'es',
          'seen_swipe_hint': true,
          ...extra,
        };

    testWidgets('Text conversation survives an app restart', (tester) async {
      SharedPreferences.setMockInitialValues(prefsWith({'app_mode': 'text'}));
      mockClipboard(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await sendInTextMode(tester, 'hello');

      // "Restart": throw away the whole provider tree, keep the stored prefs.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('hello'), findsOneWidget);
      expect(find.text('stub: hello'), findsOneWidget);
    });

    testWidgets('Saved voice conversation is restored on launch', (tester) async {
      SharedPreferences.setMockInitialValues(prefsWith({
        'conversation_voice': jsonEncode({
          'v': 1,
          'conversations': [
            {
              'id': 'current',
              'messages': [
                {'id': 0, 'original': 'hola', 'translated': 'hello', 'left': true},
              ],
            },
          ],
        }),
      }));
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.byType(ConversationPage), findsOneWidget);
      expect(find.text('hola'), findsOneWidget);
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('A translation interrupted by closing the app comes back as retryable', (tester) async {
      SharedPreferences.setMockInitialValues(prefsWith({
        'app_mode': 'text',
        'conversation_text': jsonEncode({
          'v': 1,
          'conversations': [
            {
              'id': 'current',
              'messages': [
                {'id': 3, 'original': 'hola', 'left': true},
              ],
            },
          ],
        }),
      }));
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('tap to retry'), findsOneWidget);
      await tester.tap(find.text('tap to retry'));
      await tester.pumpAndSettle();
      expect(find.text('stub: hola'), findsOneWidget);
    });

    testWidgets('Clearing removes the saved conversation too', (tester) async {
      SharedPreferences.setMockInitialValues(prefsWith({'app_mode': 'text'}));
      mockClipboard(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await sendInTextMode(tester, 'hello');
      await tester.tap(find.byTooltip('Clear conversation'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.byType(MessageBubble), findsNothing);
    });

    testWidgets('Read-back is on by default', (tester) async {
      SharedPreferences.setMockInitialValues(prefsWith({'app_mode': 'text'}));
      mockClipboard(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await sendInTextMode(tester, 'hello');
      expect(find.text('Reads back as: stub: stub: hello'), findsOneWidget);
    });

    testWidgets('Read-back line is hidden when switched off', (tester) async {
      SharedPreferences.setMockInitialValues(
        prefsWith({'app_mode': 'text', 'read_back': false}),
      );
      mockClipboard(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await sendInTextMode(tester, 'hello');
      expect(find.textContaining('Reads back as'), findsNothing);
    });

    testWidgets('Read-back line shows under your message when switched on', (tester) async {
      SharedPreferences.setMockInitialValues(
        prefsWith({'app_mode': 'text', 'read_back': true}),
      );
      mockClipboard(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await sendInTextMode(tester, 'hello');
      // The stub "translates" by prefixing, so the round trip is visible.
      expect(find.text('Reads back as: stub: stub: hello'), findsOneWidget);
    });

    test('An identical read-back (ignoring case/punctuation) is hidden', () {
      expect(readBackDiffers('Yes! See you at 7.', 'yes, see you at 7'), isFalse);
      expect(readBackDiffers('See you at 7', 'See you at 8'), isTrue);
      expect(readBackDiffers('พรุ่งนี้ว่างไหม', 'พรุ่งนี้ว่างไหม?'), isFalse);
    });

    testWidgets('Settings has the read-back switch', (tester) async {
      SharedPreferences.setMockInitialValues(prefsWith({}));
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Read-back check'), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('read_back'), isFalse); // was on by default
    });
  });

  test('translate() flags limitReached on a 429 MONTHLY_LIMIT response', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.httpClientAdapter = _FakeAdapter(
      statusCode: 429,
      body: {
        'error': 'Free translation limit reached this month',
        'code': 'MONTHLY_LIMIT',
      },
    );
    final service = TranslationService(dio: dio);

    await expectLater(
      service.translate(text: 'hallo', source: 'nl', target: 'it'),
      throwsA(isA<TranslationException>()
          .having((e) => e.limitReached, 'limitReached', isTrue)),
    );
  });

  test('translate() treats other errors as generic (retryable) failures', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.httpClientAdapter = _FakeAdapter(
      statusCode: 500,
      body: {'error': 'Translation failed'},
    );
    final service = TranslationService(dio: dio);

    await expectLater(
      service.translate(text: 'hallo', source: 'nl', target: 'it'),
      throwsA(isA<TranslationException>()
          .having((e) => e.limitReached, 'limitReached', isFalse)),
    );
  });
}

/// Minimal Dio adapter that returns a canned JSON response with a chosen
/// status code, so we can exercise TranslationService's error mapping without
/// a real network call.
class _FakeAdapter implements HttpClientAdapter {
  final int statusCode;
  final Map<String, dynamic> body;

  _FakeAdapter({required this.statusCode, required this.body});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
