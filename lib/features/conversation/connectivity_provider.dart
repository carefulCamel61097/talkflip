import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Streams a single boolean — `true` while at least one network interface
/// is connected, `false` otherwise. UI shows the offline dot when this is
/// `false`. While loading or on error, treated optimistically as online
/// (no dot) to avoid false-positive offline indicators on initial frame.
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();

  final initial = await connectivity.checkConnectivity();
  yield initial.any((r) => r != ConnectivityResult.none);

  await for (final result in connectivity.onConnectivityChanged) {
    yield result.any((r) => r != ConnectivityResult.none);
  }
});
