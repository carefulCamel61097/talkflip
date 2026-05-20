import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:talkflip/main.dart';
import 'package:talkflip/features/conversation/draft_bubble.dart';

void main() {
  testWidgets('App boots and shows both language chips', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TalkFlipApp()));
    expect(find.text('EN'), findsOneWidget);
    expect(find.text('ES'), findsOneWidget);
  });

  testWidgets('Neutral state shows no draft bubble', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TalkFlipApp()));
    expect(find.byType(DraftBubble), findsNothing);
  });

  testWidgets('Tapping EN chip activates left side and shows draft bubble', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TalkFlipApp()));
    await tester.tap(find.text('EN'));
    await tester.pump();
    expect(find.byType(DraftBubble), findsOneWidget);
  });

  testWidgets('Tapping ES chip activates right side and shows draft bubble', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TalkFlipApp()));
    await tester.tap(find.text('ES'));
    await tester.pump();
    expect(find.byType(DraftBubble), findsOneWidget);
  });

  testWidgets('Swiping right activates the left side (carousel convention)', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TalkFlipApp()));
    await tester.fling(find.byType(Scaffold), const Offset(500, 0), 1000);
    await tester.pump();
    final draft = tester.widget<DraftBubble>(find.byType(DraftBubble));
    expect(draft.isLeft, isTrue);
  });

  testWidgets('Swiping left activates the right side (carousel convention)', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TalkFlipApp()));
    await tester.fling(find.byType(Scaffold), const Offset(-500, 0), 1000);
    await tester.pump();
    final draft = tester.widget<DraftBubble>(find.byType(DraftBubble));
    expect(draft.isLeft, isFalse);
  });
}
