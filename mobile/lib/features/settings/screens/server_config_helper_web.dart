import 'dart:html' as html;
import 'dart:async';
import 'dart:convert';

class ConnectionResult {
  final bool success;
  final String? error;
  ConnectionResult(this.success, [this.error]);
}

class PlatformHelper {
  static Future<ConnectionResult> testConnection(String url) async {
    final fullUrl = '$url/health';
    try {
      final completer = Completer<html.HttpRequest>();
      final request = html.HttpRequest();
      request.open('GET', fullUrl);
      request.timeout = 3000;
      request.onLoad.listen((_) {
        if (!completer.isCompleted) completer.complete(request);
      });
      request.onError.listen((event) {
        if (!completer.isCompleted) {
          completer.completeError(html.EventException('Network error'));
        }
      });
      request.onTimeout.listen((_) {
        if (!completer.isCompleted) {
          completer.completeError(TimeoutException('Request timeout'));
        }
      });
      request.send();

      final response = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('Connection timeout'),
      );

      if (response.status == 200) {
        try {
          final data = json.decode(response.responseText ?? '');
          if (data is Map && data['status'] == 'healthy') {
            return ConnectionResult(true);
          }
          return ConnectionResult(false, '响应格式异常');
        } catch (e) {
          return ConnectionResult(false, 'JSON解析失败');
        }
      }
      return ConnectionResult(false, 'HTTP ${response.status}');
    } on TimeoutException {
      return ConnectionResult(false, '连接超时(5秒)');
    } catch (e) {
      return ConnectionResult(false, '网络错误: $e');
    }
  }
}
