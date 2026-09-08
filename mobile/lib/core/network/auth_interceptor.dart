import 'package:dio/dio.dart';

import 'access_token_holder.dart';

/// Adds the current access token to protected backend requests only.
///
/// Refresh, retries, token clearing, navigation, and error handling are
/// deliberately outside this M2.14.1 interceptor.
class AuthInterceptor extends Interceptor {
  final AccessTokenHolder _accessTokenHolder;

  AuthInterceptor(this._accessTokenHolder);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final accessToken = _accessTokenHolder.currentAccessToken;
    if (accessToken != null &&
        accessToken.trim().isNotEmpty &&
        !_isPublicPath(options.uri.path)) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }
    handler.next(options);
  }

  static bool _isPublicPath(String path) {
    return path == '/api/v1/health' || path.startsWith('/api/v1/auth/');
  }
}
