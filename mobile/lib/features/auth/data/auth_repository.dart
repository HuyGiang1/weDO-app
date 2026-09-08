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

  AuthRepository({
    required this.api,
    required this.storage,
    required this.accessTokenHolder,
  });

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

  /// Removes only the locally held authenticated session. This deliberately
  /// does not revoke remotely or affect onboarding-only credentials.
  Future<void> clearLocalSession() async {
    try {
      await storage.clearSession();
    } catch (_) {
      // Do not keep an in-memory bearer token after durable clearing failed.
      accessTokenHolder.clearAccessToken();
      throw const AuthException(AuthFailure(AuthFailureType.unexpected));
    }
    accessTokenHolder.clearAccessToken();
  }

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
