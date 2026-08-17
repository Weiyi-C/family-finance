import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:family_finance_app/data/services/api_service.dart';
import 'dart:async';
import 'dart:io' show NetworkInterface, InternetAddressType;
import 'server_config_helper.dart' if (dart.library.html) 'server_config_helper_web.dart';

class ServerConfigScreen extends StatefulWidget {
  const ServerConfigScreen({super.key});

  @override
  State<ServerConfigScreen> createState() => _ServerConfigScreenState();
}

class _ServerConfigScreenState extends State<ServerConfigScreen> {
  final _urlController = TextEditingController();
  bool _isTesting = false;
  bool _isScanning = false;
  String? _status;
  final List<String> _scanResults = [];
  int _scanProgress = 0;
  int _scanTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadServerUrl();
  }

  Future<void> _loadServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    _urlController.text = prefs.getString('server_url') ?? 'http://192.168.31.9:8080';
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('服务器配置'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '服务器地址',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '输入服务器地址（支持 IP:端口 或域名），自动检测 HTTP/HTTPS',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        labelText: '服务器地址',
                        hintText: '例如 192.168.1.100:8080',
                        prefixIcon: Icon(Icons.dns),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isTesting ? null : _testConnection,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_find),
                    label: Text(_isTesting ? '测试中...' : '测试连接'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveServerUrl,
                    icon: const Icon(Icons.save),
                    label: const Text('保存'),
                  ),
                ),
              ],
            ),
            if (_status != null) ...[
              const SizedBox(height: 16),
              Card(
                color: _status!.contains('成功') ? Colors.green[50] : Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        _status!.contains('成功') ? Icons.check_circle : Icons.error,
                        color: _status!.contains('成功') ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_status!)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '自动发现',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '自动扫描当前局域网段（常见端口 8080/8000）',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isScanning ? null : _scanLAN,
                      icon: _isScanning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.radar),
                      label: Text(_isScanning ? '扫描中 $_scanProgress/$_scanTotal...' : '扫描局域网'),
                    ),
                    if (_scanResults.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      ...(_scanResults.map((ip) => ListTile(
                            leading: const Icon(Icons.dns, color: Colors.green),
                            title: Text(ip),
                            trailing: TextButton(
                              onPressed: () {
                                _urlController.text = ip;
                              },
                              child: const Text('使用'),
                            ),
                          ))),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _normalizeUrl(String input) {
    String host = input.trim();
    if (host.startsWith('http://')) {
      host = host.substring(7);
    } else if (host.startsWith('https://')) {
      host = host.substring(8);
    }
    host = host.replaceAll(RegExp(r'/+$'), '');
    return host;
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _status = null;
    });

    final input = _urlController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _status = '连接失败：请输入服务器地址';
        _isTesting = false;
      });
      return;
    }

    final host = _normalizeUrl(input);
    final urlsToTry = ['http://$host', 'https://$host'];
    String? successUrl;
    String? lastError;

    for (final baseUrl in urlsToTry) {
      final result = await PlatformHelper.testConnection(baseUrl);
      if (result.success) {
        successUrl = baseUrl;
        break;
      } else {
        lastError = result.error;
      }
    }

    if (successUrl != null) {
      final protocol = successUrl.startsWith('https') ? 'HTTPS' : 'HTTP';
      _urlController.text = successUrl;
      setState(() {
        _status = '连接成功！使用 $protocol 协议';
      });
    } else {
      setState(() {
        _status = '连接失败：$lastError';
      });
    }

    setState(() => _isTesting = false);
  }

  Future<void> _saveServerUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入服务器地址')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', url);
    await ApiService().setBaseUrl(url);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('服务器地址已保存')),
      );
      Navigator.pop(context);
    }
  }

  Future<List<String>> _getLocalSubnets() async {
    final subnets = <String>{};

    final currentUrl = _urlController.text.trim();
    if (currentUrl.isNotEmpty) {
      final host = _normalizeUrl(currentUrl);
      final ipPart = host.split(':').first;
      final parts = ipPart.split('.');
      if (parts.length == 4) {
        subnets.add('${parts[0]}.${parts[1]}.${parts[2]}');
      }
    }

    try {
      for (final iface in await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      )) {
        for (final addr in iface.addresses) {
          final parts = addr.address.split('.');
          if (parts.length == 4) {
            subnets.add('${parts[0]}.${parts[1]}.${parts[2]}');
          }
        }
      }
    } catch (_) {}

    if (subnets.isEmpty) {
      subnets.add('192.168.1');
      subnets.add('192.168.0');
      subnets.add('192.168.31');
    }

    return subnets.toList();
  }

  Future<void> _scanLAN() async {
    setState(() {
      _isScanning = true;
      _scanResults.clear();
      _scanProgress = 0;
    });

    final commonPorts = [8080, 8000];
    final subnets = await _getLocalSubnets();
    final found = <String>[];
    var scanned = 0;
    var stopped = false;

    for (final subnet in subnets) {
      if (stopped) break;

      final total = 254 * commonPorts.length;
      setState(() => _scanTotal = total);
      scanned = 0;

      for (var batch = 1; batch <= 254; batch += 20) {
        if (stopped) break;

        final futures = <Future<void>>[];
        for (var i = batch; i < batch + 20 && i <= 254; i++) {
          for (final port in commonPorts) {
            final ip = '$subnet.$i';
            final url = 'http://$ip:$port';
            futures.add(
              PlatformHelper.testConnection(url).then((result) {
                if (result.success && !found.contains('$ip:$port') && !stopped) {
                  found.add('$ip:$port');
                  setState(() {
                    _scanResults.add('$ip:$port');
                  });
                  if (found.length >= 3) stopped = true;
                }
              }),
            );
          }
        }

        await Future.wait(futures);
        scanned += 20 * commonPorts.length;
        setState(() => _scanProgress = scanned);
      }
    }

    if (mounted) {
      setState(() {
        _isScanning = false;
        if (found.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未发现局域网服务器')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('发现 ${found.length} 个服务器')),
          );
        }
      });
    }
  }
}
