import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:talkflip/main.dart';

void main() {
  testWidgets('App boots and shows TalkFlip placeholder', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TalkFlipApp()));
    expect(find.text('TalkFlip'), findsOneWidget);
  });
}
