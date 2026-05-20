import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:talkflip/main.dart';
import 'package:talkflip/features/conversation/draft_bubble.dart';
import 'package:talkflip/features/conversation/language_picker_page.dart';
import 'package:talkflip/features/conversation/translation_service.dart';

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
    child: const TalkFlipApp(),
  );
}

void main() {
  setUp(() {
    // Default: a language pair is already stored, so tests skip the picker
    // and land on the conversation page.
    SharedPreferences.setMockInitialValues({
      'language_pair_left': 'en',
      'language_pair_right': 'es',
    });
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
    await tester.pump();
    expect(find.byType(DraftBubble), findsOneWidget);
  });

  testWidgets('Tapping ES chip activates right side and shows draft bubble', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('ES'));
    await tester.pump();
    expect(find.byType(DraftBubble), findsOneWidget);
  });

  testWidgets('Swiping right activates the left side (carousel convention)', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.fling(find.byType(Scaffold), const Offset(500, 0), 1000);
    await tester.pump();
    final draft = tester.widget<DraftBubble>(find.byType(DraftBubble));
    expect(draft.isLeft, isTrue);
  });

  testWidgets('Swiping left activates the right side (carousel convention)', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.fling(find.byType(Scaffold), const Offset(-500, 0), 1000);
    await tester.pump();
    final draft = tester.widget<DraftBubble>(find.byType(DraftBubble));
    expect(draft.isLeft, isFalse);
  });
}
