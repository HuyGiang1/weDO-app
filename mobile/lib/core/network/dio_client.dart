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
    this.dio.options
      ..baseUrl = apiConfig.baseUrl
      ..connectTimeout = const Duration(seconds: 15)
      ..sendTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 30)
      ..contentType = Headers.jsonContentType
      ..responseType = ResponseType.json;
    this.dio.options.headers['Accept'] = 'application/json';

    if (!this.dio.interceptors.any(
      (interceptor) => interceptor is AuthInterceptor,
    )) {
      this.dio.interceptors.add(AuthInterceptor(accessTokenHolder));
    }
  }
}
