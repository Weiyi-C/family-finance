import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';

class ConnectionResult {
  final bool success;
  final String? error;
  ConnectionResult(this.success, [this.error]);
}

class DiscoveryResult {
  final String ip;
  final int port;
  final String name;
  DiscoveryResult(this.ip, this.port, this.name);
}

class PlatformHelper {
  static const _channel = MethodChannel('com.familyfinance/wifi');

  static Future<ConnectionResult> testConnection(String url) async {
    final uri = Uri.parse('$url/health');
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(uri);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode == 200) {
        final data = json.decode(body);
        if (data is Map && data['status'] == 'healthy') {
          return ConnectionResult(true);
        }
        return ConnectionResult(false, '响应异常: $body');
      }
      return ConnectionResult(false, 'HTTP ${response.statusCode}');
    } catch (e) {
      return ConnectionResult(false, '${e.runtimeType}: $e');
    }
  }

  static Future<List<DiscoveryResult>> discoverServers() async {
    final results = <DiscoveryResult>[];
    const discoveryPort = 9876;
    const message = 'discover_family_finance';

    try {
      await _channel.invokeMethod('acquireMulticastLock');
    } catch (_) {}

    try {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );
      socket.broadcastEnabled = true;

      final targets = <InternetAddress>[];

      try {
        for (final iface in await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLinkLocal: false,
        )) {
          for (final addr in iface.addresses) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
              targets.add(InternetAddress('$prefix.255'));
              targets.add(InternetAddress('$prefix.1'));
            }
          }
        }
      } catch (_) {}

      targets.add(InternetAddress('255.255.255.255'));

      for (var i = 0; i < 3; i++) {
        for (final target in targets) {
          try {
            socket.send(message.codeUnits, target, discoveryPort);
          } catch (_) {}
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final completer = Completer<void>();
      final timer = Timer(const Duration(seconds: 3), () {
        if (!completer.isCompleted) completer.complete();
      });

      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null) {
            try {
              final data = json.decode(String.fromCharCodes(datagram.data));
              if (data is Map && data['magic'] == 'family_finance_server') {
                final ip = data['ip'] as String;
                final port = data['port'] as int;
                final name = data['name'] as String? ?? '家庭记账服务器';
                final addr = '$ip:$port';
                if (!results.any((r) => '${r.ip}:${r.port}' == addr)) {
                  results.add(DiscoveryResult(ip, port, name));
                }
              }
            } catch (_) {}
          }
        }
      });

      await completer.future;
      timer.cancel();
      socket.close();
    } catch (_) {}

    try {
      await _channel.invokeMethod('releaseMulticastLock');
    } catch (_) {}

    return results;
  }
}
