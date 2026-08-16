import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:html' as html;
import 'dart:async';
import 'dart:convert';

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

  @override
  void initState() {
    super.initState();
    _loadServerUrl();
  }

  Future<void> _loadServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    _urlController.text = prefs.getString('server_url') ?? 'http://192.168.1.100:8080';
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
      body: Padding(
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
                      '扫描局域网中的服务器（常见端口 8080/8000）',
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
                      label: Text(_isScanning ? '扫描中...' : '扫描局域网'),
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

    String host = input;
    if (host.startsWith('http://')) {
      host = host.substring(7);
    } else if (host.startsWith('https://')) {
      host = host.substring(8);
    }
    host = host.replaceAll(RegExp(r'/+$'), '');

    final urlsToTry = ['http://$host', 'https://$host'];
    String? successUrl;
    String lastError = '无法连接到服务器';

    for (final baseUrl in urlsToTry) {
      try {
        final completer = Completer<html.HttpRequest>();
        final request = html.HttpRequest();
        request.open('GET', '$baseUrl/health');
        request.timeout = 3000;
        request.onLoad.listen((_) {
          if (!completer.isCompleted) completer.complete(request);
        });
        request.onError.listen((_) {
          if (!completer.isCompleted) {
            completer.completeError('网络错误');
          }
        });
        request.onTimeout.listen((_) {
          if (!completer.isCompleted) {
            completer.completeError('连接超时');
          }
        });
        request.send();

        final response = await completer.future.timeout(
          const Duration(seconds: 4),
          onTimeout: () => throw TimeoutException('连接超时'),
        );

        if (response.status == 200) {
          try {
            final data = json.decode(response.responseText ?? '');
            if (data is Map && data['status'] == 'healthy') {
              successUrl = baseUrl;
              break;
            } else {
              lastError = '服务器响应格式异常';
            }
          } catch (_) {
            lastError = '服务器响应格式异常';
          }
        } else {
          lastError = '服务器返回状态码 ${response.status}';
        }
      } on TimeoutException {
        lastError = '连接超时（4秒）';
      } catch (e) {
        lastError = '连接失败：$e';
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

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('服务器地址已保存')),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _scanLAN() async {
    setState(() {
      _isScanning = true;
      _scanResults.clear();
    });

    final commonPorts = [8080, 8000];
    final found = <String>[];

    for (var i = 1; i <= 20; i++) {
      for (final port in commonPorts) {
        final ip = '192.168.1.$i';
        final url = 'http://$ip:$port';
        try {
          final completer = Completer<html.HttpRequest>();
          final request = html.HttpRequest();
          request.open('GET', '$url/health');
          request.timeout = 500;
          request.onLoad.listen((_) {
            if (!completer.isCompleted) completer.complete(request);
          });
          request.onError.listen((_) {
            if (!completer.isCompleted) completer.completeError('error');
          });
          request.onTimeout.listen((_) {
            if (!completer.isCompleted) completer.completeError('timeout');
          });
          request.send();

          final response = await completer.future.timeout(
            const Duration(milliseconds: 600),
            onTimeout: () => throw TimeoutException('timeout'),
          );

          if (response.status == 200) {
            try {
              final data = json.decode(response.responseText ?? '');
              if (data is Map && data['status'] == 'healthy') {
                found.add('$ip:$port');
              }
            } catch (_) {}
          }
        } catch (_) {}
      }
    }

    if (mounted) {
      setState(() {
        _isScanning = false;
        _scanResults.addAll(found);
        if (found.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未发现局域网服务器')),
          );
        }
      });
    }
  }
}
