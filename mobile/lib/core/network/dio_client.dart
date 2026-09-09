import 'package:dio/dio.dart';

import 'api_config.dart';
import 'auth_interceptor.dart';

/// Reusable HTTP client foundation.
class DioClient {
  final Dio dio;

  DioClient({
    required ApiConfig apiConfig,
    Dio? dio,
  }) : dio = dio ?? Dio() {
    _configureOptions(this.dio, apiConfig);
  }

  factory DioClient.withAuthInterceptor({
    required ApiConfig apiConfig,
    required AuthInterceptor interceptor,
    Dio? dio,
  }) {
    final client = DioClient(apiConfig: apiConfig, dio: dio);
    client.attachAuthInterceptor(interceptor);
    return client;
  }

  /// Creates an interceptor-free client sharing the same baseUrl, timeout,
  /// and JSON configuration. Used specifically for isolated token refresh.
  factory DioClient.raw({
    required ApiConfig apiConfig,
    Dio? dio,
  }) {
    final client = dio ?? Dio();
    _configureOptions(client, apiConfig);
    // Dio's Interceptors.clear() re-adds ImplyContentTypeInterceptor by default.
    // removeWhere((_) => true) guarantees physically zero interceptors.
    client.interceptors.removeWhere((_) => true);
    return DioClient._(client);
  }

  DioClient._(this.dio);

  void attachAuthInterceptor(AuthInterceptor interceptor) {
    if (!dio.interceptors.contains(interceptor)) {
      dio.interceptors.add(interceptor);
    }
  }

  static void _configureOptions(Dio dio, ApiConfig apiConfig) {
    dio.options
      ..baseUrl = apiConfig.baseUrl
      ..connectTimeout = const Duration(seconds: 15)
      ..sendTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 30)
      ..contentType = Headers.jsonContentType
      ..responseType = ResponseType.json;
    dio.options.headers['Accept'] = 'application/json';
  }
}
