import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:talkflip/main.dart';

void main() {
  testWidgets('App boots and shows both language chips', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TalkFlipApp()));
    expect(find.text('EN'), findsOneWidget);
    expect(find.text('ES'), findsOneWidget);
  });
}
