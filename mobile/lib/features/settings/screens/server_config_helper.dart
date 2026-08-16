import 'dart:io';
import 'dart:convert';

class ConnectionResult {
  final bool success;
  final String? error;
  ConnectionResult(this.success, [this.error]);
}

class PlatformHelper {
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
}
