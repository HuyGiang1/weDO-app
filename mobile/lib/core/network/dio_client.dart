import 'package:dio/dio.dart';

import 'access_token_holder.dart';
import 'api_config.dart';
import 'auth_interceptor.dart';

/// Reusable HTTP client foundation. Endpoint methods belong to AuthApi later.
class DioClient {
  final Dio dio;

  DioClient({
    required ApiConfig apiConfig,
    required AccessTokenHolder accessTokenHolder,
    Dio? dio,
  }) : dio = dio ?? Dio() {
    _configureOptions(this.dio, apiConfig);
    if (!this.dio.interceptors.any(
      (interceptor) => interceptor is AuthInterceptor,
    )) {
      this.dio.interceptors.add(AuthInterceptor(accessTokenHolder));
    }
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
