import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:talkflip/main.dart';
import 'package:talkflip/features/conversation/conversation_page.dart';
import 'package:talkflip/features/conversation/draft_bubble.dart';
import 'package:talkflip/features/conversation/language_picker_page.dart';
import 'package:talkflip/features/conversation/translation_service.dart';
import 'package:talkflip/features/settings/settings_page.dart';

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

Widget _app() {
  return ProviderScope(
    overrides: [
      translationServiceProvider.overrideWith((ref) => _StubTranslationService()),
    ],
    child: const ConvoGoApp(),
  );
}

void main() {
  setUp(() {
    // Default: a language pair is already stored, so tests skip the picker
    // and land on the conversation page. seen_swipe_hint is pre-set so the
    // first-launch snackbar doesn't appear and interfere with assertions.
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

  testWidgets('Tapping EN chip activates left side and shows draft bubble', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    expect(find.byType(DraftBubble), findsOneWidget);
  });

  testWidgets('Tapping ES chip activates right side and shows draft bubble', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('ES'));
    await tester.pumpAndSettle();
    expect(find.byType(DraftBubble), findsOneWidget);
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
    expect(find.text('Clear conversation'), findsOneWidget);
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
