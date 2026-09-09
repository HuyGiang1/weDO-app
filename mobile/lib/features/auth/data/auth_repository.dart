import 'dart:async';

import '../../../core/auth/session_revision.dart';
import '../../../core/network/access_token_holder.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_storage_service.dart';
import 'auth_api.dart';
import 'auth_failure.dart';
import 'models/auth_models.dart';

class LogoutResult {
  final bool remoteRevocationSucceeded;
  const LogoutResult(this.remoteRevocationSucceeded);
}

class AuthRepository {
  final AuthApi api;
  final SecureStorageService storage;
  final AccessTokenHolder accessTokenHolder;

  final List<Future<void> Function()> _mutationQueue = [];
  bool _isProcessingMutationQueue = false;

  AuthRepository({
    required this.api,
    required this.storage,
    required this.accessTokenHolder,
  });

  Future<T> _runExclusiveSessionMutation<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _mutationQueue.add(() async {
      try {
        final result = await action();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    _processMutationQueue();
    return completer.future;
  }

  Future<void> _processMutationQueue() async {
    if (_isProcessingMutationQueue) return;
    _isProcessingMutationQueue = true;
    while (_mutationQueue.isNotEmpty) {
      final task = _mutationQueue.removeAt(0);
      try {
        await task();
      } catch (_) {
        // Handled via task completer
      }
    }
    _isProcessingMutationQueue = false;
  }

  Future<T> _guard<T>(Future<T> Function() work) async {
    try {
      return await work();
    } on ApiException catch (e) {
      throw AuthException(AuthFailure.fromApi(e));
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(AuthFailure(AuthFailureType.unexpected));
    }
  }

  String _email(String value) => value.trim().toLowerCase();

  Future<RegisterResult> register({
    required String email,
    required String password,
  }) => _guard(() => api.register(email: _email(email), password: password));

  Future<VerifyEmailResult> verifyEmail({
    required String userId,
    required String code,
  }) => _guard(() => api.verifyEmail(userId: userId, code: code));

  Future<ResendVerificationResult> resendVerification(String userId) =>
      _guard(() => api.resendVerification(userId));

  Future<UsernameAvailabilityResult> checkUsernameAvailability(
    String username,
  ) => _guard(() => api.checkUsernameAvailability(username.toLowerCase()));

  Future<CompleteProfileResult> completeProfile({
    required String profileCompletionToken,
    required String username,
    required String displayName,
    String? bio,
    String? avatarStorageKey,
  }) => _guard(
    () => api.completeProfile(
      profileCompletionToken: profileCompletionToken,
      username: username.toLowerCase(),
      displayName: displayName,
      bio: bio,
      avatarStorageKey: avatarStorageKey,
    ),
  );

  Future<LoginResult> login({
    required String email,
    required String password,
    String? deviceName,
  }) => _guard(() async {
    final result = await api.login(
      email: _email(email),
      password: password,
      deviceName: deviceName,
    );
    if (result is AuthenticatedSession) {
      if (result.accessToken.trim().isEmpty ||
          result.refreshToken.trim().isEmpty) {
        throw const AuthException(AuthFailure(AuthFailureType.unexpected));
      }
      await _runExclusiveSessionMutation(() async {
        try {
          await storage.writeSession(
            accessToken: result.accessToken,
            refreshToken: result.refreshToken,
          );
          accessTokenHolder.setAccessToken(result.accessToken);
        } catch (_) {
          accessTokenHolder.clearAccessToken();
          throw const AuthException(AuthFailure(AuthFailureType.unexpected));
        }
      });
    }
    return result;
  });

  Future<ForgotPasswordResult> forgotPassword(String email) =>
      _guard(() => api.forgotPassword(_email(email)));

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) => _guard(
    () => api.resetPassword(
      email: _email(email),
      code: code,
      newPassword: newPassword,
    ),
  );

  Future<CurrentUser> getCurrentUser() => _guard(api.getCurrentUser);

  /// Rotates the authenticated session using the stored refresh token.
  ///
  /// Atomically updates durable storage before updating [AccessTokenHolder].
  /// Serialized through [_credentialMutationQueue] and generation-consistent
  /// with [expectedRevision].
  Future<SessionRevisionTransition> refreshSession({
    required int expectedRevision,
  }) async {
    // 1. Generation-consistent snapshot inside mutation queue
    final String refreshTokenToUse =
        await _runExclusiveSessionMutation(() async {
      if (accessTokenHolder.revision != expectedRevision) {
        throw const AuthException(
          AuthFailure(AuthFailureType.refreshSessionSuperseded),
        );
      }
      final token = await storage.readRefreshToken();
      if (token == null || token.trim().isEmpty) {
        throw const AuthException(
          AuthFailure(AuthFailureType.noRefreshableSession),
        );
      }
      return token;
    });

    // 2. Network call OUTSIDE mutation queue
    RefreshTokenResponse response;
    try {
      response = await api.refreshToken(refreshTokenToUse);
    } on ApiException catch (e) {
      throw AuthException(AuthFailure.fromApi(e));
    } catch (_) {
      // Malformed HTTP-200 success response or decode failure.
      // Must be generation-aware before destructive cleanup:
      await _runExclusiveSessionMutation(() async {
        if (accessTokenHolder.revision != expectedRevision) {
          throw const AuthException(
            AuthFailure(AuthFailureType.refreshSessionSuperseded),
          );
        }
        accessTokenHolder.clearAccessToken();
        await _clearSessionBestEffort();
        throw const AuthException(
          AuthFailure(AuthFailureType.refreshSessionUnrecoverable),
        );
      });
    }

    // 3. Compare and Adopt inside mutation queue
    return await _runExclusiveSessionMutation(() async {
      if (accessTokenHolder.revision != expectedRevision) {
        throw const AuthException(
          AuthFailure(AuthFailureType.refreshSessionSuperseded),
        );
      }

      if (response.accessToken.trim().isEmpty ||
          response.refreshToken.trim().isEmpty ||
          response.tokenType != 'Bearer') {
        accessTokenHolder.clearAccessToken();
        await _clearSessionBestEffort();
        throw const AuthException(
          AuthFailure(AuthFailureType.refreshSessionUnrecoverable),
        );
      }

      try {
        await storage.writeSession(
          accessToken: response.accessToken,
          refreshToken: response.refreshToken,
        );
      } catch (_) {
        accessTokenHolder.clearAccessToken();
        await _clearSessionBestEffort();
        throw const AuthException(
          AuthFailure(AuthFailureType.refreshSessionUnrecoverable),
        );
      }

      accessTokenHolder.setAccessToken(response.accessToken);
      final toRevision = accessTokenHolder.revision;

      return SessionRevisionTransition(
        fromRevision: expectedRevision,
        toRevision: toRevision,
      );
    });
  }

  Future<void> _clearSessionBestEffort() async {
    try {
      await storage.clearSession();
    } catch (_) {
      // Best-effort cleanup
    }
  }

  /// Removes only the locally held authenticated session. This deliberately
  /// does not revoke remotely or affect onboarding-only credentials.
  Future<void> clearLocalSession() => _runExclusiveSessionMutation(() async {
    try {
      await storage.clearSession();
    } catch (_) {
      // Do not keep an in-memory bearer token after durable clearing failed.
      accessTokenHolder.clearAccessToken();
      throw const AuthException(AuthFailure(AuthFailureType.unexpected));
    }
    accessTokenHolder.clearAccessToken();
  });

  Future<LogoutResult> logout() async {
    var remoteRevocationSucceeded = true;
    final refreshToken = await storage.readRefreshToken();
    try {
      if (refreshToken != null && refreshToken.trim().isNotEmpty) {
        await api.logout(refreshToken);
      }
    } catch (_) {
      remoteRevocationSucceeded = false;
    } finally {
      await clearLocalSession();
    }
    return LogoutResult(remoteRevocationSucceeded);
  }
}
