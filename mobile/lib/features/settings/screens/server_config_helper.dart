import 'dart:io';
import 'dart:async';
import 'dart:convert';

class PlatformHelper {
  static Future<bool> testConnection(String url) async {
    try {
      final uri = Uri.parse('$url/health');
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 2);
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw TimeoutException('timeout'),
      );

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = json.decode(body);
        return data is Map && data['status'] == 'healthy';
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
