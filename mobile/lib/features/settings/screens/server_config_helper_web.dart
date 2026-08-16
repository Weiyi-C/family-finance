import 'dart:html' as html;
import 'dart:async';
import 'dart:convert';

class PlatformHelper {
  static Future<bool> testConnection(String url) async {
    try {
      final completer = Completer<html.HttpRequest>();
      final request = html.HttpRequest();
      request.open('GET', '$url/health');
      request.timeout = 2000;
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
        const Duration(seconds: 3),
        onTimeout: () => throw Exception('timeout'),
      );

      if (response.status == 200) {
        final data = json.decode(response.responseText ?? '');
        return data is Map && data['status'] == 'healthy';
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
