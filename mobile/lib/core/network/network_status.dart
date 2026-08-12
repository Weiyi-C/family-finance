import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NetworkStatus {
  online,
  offline,
  unknown,
}

final networkStatusProvider = StateNotifierProvider<NetworkStatusNotifier, NetworkStatus>((ref) {
  return NetworkStatusNotifier();
});

class NetworkStatusNotifier extends StateNotifier<NetworkStatus> {
  Timer? _checkTimer;
  
  NetworkStatusNotifier() : super(NetworkStatus.unknown) {
    _startChecking();
  }
  
  void _startChecking() {
    // 每30秒检查一次网络状态
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      checkConnection();
    });
    // 立即检查一次
    checkConnection();
  }
  
  Future<void> checkConnection() async {
    try {
      // TODO: 实现实际的网络连接检测
      // 可以通过ping服务器或检查API响应
      state = NetworkStatus.online;
    } catch (e) {
      state = NetworkStatus.offline;
    }
  }
  
  void setOnline() => state = NetworkStatus.online;
  void setOffline() => state = NetworkStatus.offline;
  
  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }
}
