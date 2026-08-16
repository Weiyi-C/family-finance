import 'package:http/http.dart' as http;
import 'dart:convert';

class PlatformHelper {
  static Future<bool> testConnection(String url) async {
    try {
      final response = await http.get(
        Uri.parse('$url/health'),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data is Map && data['status'] == 'healthy';
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
