import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NetworkStatus {
  online,
  offline,
  unknown,
}

final networkStatusProvider = StateNotifierProvider<NetworkStatusNotifier, NetworkStatus>((ref) {
  final notifier = NetworkStatusNotifier();
  ref.onDispose(() => notifier.dispose());
  return notifier;
});

class NetworkStatusNotifier extends StateNotifier<NetworkStatus> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  NetworkStatusNotifier() : super(NetworkStatus.unknown) {
    _init();
  }

  Future<void> _init() async {
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results);

    _subscription = _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final hasConnection = results.any((r) => r != ConnectivityResult.none);
    state = hasConnection ? NetworkStatus.online : NetworkStatus.offline;
  }

  Future<void> checkConnection() async {
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results);
  }

  void setOnline() => state = NetworkStatus.online;
  void setOffline() => state = NetworkStatus.offline;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
