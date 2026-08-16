import 'package:dio/dio.dart';

class ConnectionResult {
  final bool success;
  final String? error;
  ConnectionResult(this.success, [this.error]);
}

class PlatformHelper {
  static Future<ConnectionResult> testConnection(String url) async {
    final fullUrl = '$url/health';
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 3),
      ));
      final response = await dio.get(fullUrl);

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['status'] == 'healthy') {
          return ConnectionResult(true);
        }
        return ConnectionResult(false, '响应格式异常');
      }
      return ConnectionResult(false, 'HTTP ${response.statusCode}');
    } on DioException catch (e) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return ConnectionResult(false, '连接超时');
        case DioExceptionType.connectionError:
          return ConnectionResult(false, '无法连接，请检查地址和网络');
        default:
          return ConnectionResult(false, '网络错误: ${e.message}');
      }
    } catch (e) {
      return ConnectionResult(false, '错误: $e');
    }
  }
}
