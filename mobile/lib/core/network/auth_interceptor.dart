import 'dart:convert';

import 'package:dio/dio.dart';

import '../auth/session_revision.dart';
import 'access_token_holder.dart';

typedef RefreshSessionCallback = Future<SessionRevisionTransition> Function({
  required int expectedRevision,
});

/// Internal marker exception when a retry is aborted before dispatch because
/// the session generation changed.
class RetryAbortedException implements Exception {
  final String message;
  const RetryAbortedException(this.message);

  @override
  String toString() => 'RetryAbortedException: $message';
}

/// Adds the current access token to protected backend requests and handles
/// generation-scoped single-flight token refresh with stale-401 and TOCTOU protection.
class AuthInterceptor extends Interceptor {
  static const String _requestRevisionKey = '@wedo/auth_request_revision';
  static const String _retriedKey = '@wedo/auth_retried';
  static const String _retryTargetRevisionKey =
      '@wedo/auth_retry_target_revision';

  final AccessTokenHolder accessTokenHolder;
  final RefreshSessionCallback refreshSession;
  final Dio dio;

  SessionRevisionTransition? _lastSuccessfulRefreshTransition;
  Future<SessionRevisionTransition>? _activeRefreshFuture;
  int? _activeRefreshFromRevision;

  AuthInterceptor({
    required this.accessTokenHolder,
    required this.refreshSession,
    required this.dio,
  });

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_isPublicPath(options.uri.path)) {
      return handler.next(options);
    }

    final targetRevision = options.extra[_retryTargetRevisionKey] as int?;
    if (targetRevision != null) {
      // Mandatory TOCTOU Guard:
      // The session must still be exactly targetRevision with non-blank access token.
      final currentAccessToken = accessTokenHolder.currentAccessToken;
      if (accessTokenHolder.revision != targetRevision ||
          currentAccessToken == null ||
          currentAccessToken.trim().isEmpty) {
        // Session changed after retry authorization (e.g. Account B logged in).
        // Abort retry immediately without sending network request or attaching token!
        return handler.reject(
          DioException(
            requestOptions: options,
            error: const RetryAbortedException(
              'Session generation changed before dispatch.',
            ),
            type: DioExceptionType.cancel,
            message:
                'Retry aborted: session generation changed before dispatch.',
          ),
        );
      }
    }

    final accessToken = accessTokenHolder.currentAccessToken;
    if (accessToken != null && accessToken.trim().isNotEmpty) {
      options.headers.remove('authorization');
      options.headers['Authorization'] = 'Bearer $accessToken';
      options.extra[_requestRevisionKey] = accessTokenHolder.revision;
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    if (response?.statusCode != 401 ||
        _isPublicPath(err.requestOptions.uri.path) ||
        !_isTokenExpired(err)) {
      return handler.next(err);
    }

    // Check if already retried
    if (err.requestOptions.extra[_retriedKey] == true) {
      return handler.next(err);
    }

    final requestRev = err.requestOptions.extra[_requestRevisionKey] as int?;
    if (requestRev == null) {
      return handler.next(err);
    }

    final currentRev = accessTokenHolder.revision;
    final lastTransition = _lastSuccessfulRefreshTransition;

    // 1. Proven Stale-401 Check:
    if (lastTransition != null &&
        requestRev == lastTransition.fromRevision &&
        currentRev == lastTransition.toRevision) {
      return _retryRequest(err, lastTransition.toRevision, handler);
    }

    // 2. Active Session Expired Check:
    if (requestRev == currentRev) {
      if (_activeRefreshFuture != null &&
          _activeRefreshFromRevision != requestRev) {
        // A refresh operation for a different generation is currently in flight.
        // Fail closed: do not join, do not overwrite metadata, propagate error.
        return handler.next(err);
      }

      final SessionRevisionTransition transition;
      try {
        transition = await _performRefresh(requestRev);
      } catch (refreshError) {
        return handler.next(err.copyWith(error: refreshError));
      }

      return _retryRequest(err, transition.toRevision, handler);
    }

    // 3. Otherwise, generation changed due to login, logout, or superseded session:
    // DO NOT retry old request.
    return handler.next(err);
  }

  Future<SessionRevisionTransition> _performRefresh(int expectedRevision) {
    if (_activeRefreshFuture != null) {
      if (_activeRefreshFromRevision == expectedRevision) {
        return _activeRefreshFuture!;
      }
      throw StateError(
        'Cannot refresh for generation $expectedRevision while '
        'generation $_activeRefreshFromRevision is active.',
      );
    }

    _activeRefreshFromRevision = expectedRevision;
    final refreshFuture = refreshSession(expectedRevision: expectedRevision)
        .then((transition) {
      _lastSuccessfulRefreshTransition = transition;
      return transition;
    }).whenComplete(() {
      if (_activeRefreshFromRevision == expectedRevision) {
        _activeRefreshFuture = null;
        _activeRefreshFromRevision = null;
      }
    });

    _activeRefreshFuture = refreshFuture;
    return refreshFuture;
  }

  Future<void> _retryRequest(
    DioException originalErr,
    int targetRevision,
    ErrorInterceptorHandler handler,
  ) async {
    final requestOptions = originalErr.requestOptions;
    requestOptions.extra[_retriedKey] = true;
    requestOptions.extra[_retryTargetRevisionKey] = targetRevision;

    try {
      final response = await dio.fetch<dynamic>(requestOptions);
      handler.resolve(response);
    } on DioException catch (retryErr) {
      if (retryErr.error is RetryAbortedException) {
        handler.next(originalErr);
      } else {
        handler.next(retryErr);
      }
    } catch (e) {
      handler.next(originalErr.copyWith(error: e));
    }
  }

  static bool _isTokenExpired(DioException err) {
    var data = err.response?.data;
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {
        return false;
      }
    }
    if (data is Map) {
      return data['code'] == 'AUTH_TOKEN_EXPIRED';
    }
    return false;
  }

  static bool _isPublicPath(String path) {
    return path == '/api/v1/health' || path.startsWith('/api/v1/auth/');
  }
}
