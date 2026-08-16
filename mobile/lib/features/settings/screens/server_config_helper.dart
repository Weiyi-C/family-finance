import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as dev;

class ConnectionResult {
  final bool success;
  final String? error;
  ConnectionResult(this.success, [this.error]);
}

class PlatformHelper {
  static Future<ConnectionResult> testConnection(String url) async {
    final fullUrl = '$url/health';
    dev.log('testConnection: trying $fullUrl', name: 'PlatformHelper');
    try {
      final response = await http.get(
        Uri.parse(fullUrl),
      ).timeout(const Duration(seconds: 5));

      dev.log('testConnection: status=${response.statusCode}, body=${response.body}', name: 'PlatformHelper');

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          if (data is Map && data['status'] == 'healthy') {
            return ConnectionResult(true);
          }
          return ConnectionResult(false, '响应格式异常: ${response.body.substring(0, 100)}');
        } catch (e) {
          return ConnectionResult(false, 'JSON解析失败: ${response.body.substring(0, 100)}');
        }
      }
      return ConnectionResult(false, 'HTTP ${response.statusCode}');
    } on http.ClientException catch (e) {
      dev.log('testConnection: ClientException: ${e.message}', name: 'PlatformHelper');
      return ConnectionResult(false, '网络错误: ${e.message}');
    } on FormatException catch (e) {
      dev.log('testConnection: FormatException: ${e.message}', name: 'PlatformHelper');
      return ConnectionResult(false, 'URL格式错误: ${e.message}');
    } catch (e) {
      dev.log('testConnection: unknown error: $e', name: 'PlatformHelper');
      return ConnectionResult(false, '未知错误: $e');
    }
  }
}
