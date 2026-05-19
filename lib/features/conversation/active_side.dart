import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ActiveSide { neutral, left, right }

class ActiveSideNotifier extends Notifier<ActiveSide> {
  @override
  ActiveSide build() => ActiveSide.neutral;

  void activate(ActiveSide side) {
    state = side;
  }
}

final activeSideProvider = NotifierProvider<ActiveSideNotifier, ActiveSide>(
  ActiveSideNotifier.new,
);
