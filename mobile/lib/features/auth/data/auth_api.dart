import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import 'models/auth_models.dart';

class AuthApi {
  final Dio dio;
  final Dio refreshDio;

  AuthApi(
    this.dio, {
    required this.refreshDio,
  });

  Future<T> _call<T>(
    Future<Response<dynamic>> Function() request,
    T Function(Map<String, dynamic>) parse,
  ) async {
    try {
      final response = await request();
      final data = response.data;
      if (data is! Map) throw const FormatException('Expected JSON object');
      try {
        return parse(Map<String, dynamic>.from(data));
      } on FormatException {
        rethrow;
      } catch (e) {
        throw FormatException('Malformed response payload: $e');
      }
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> _empty(Future<Response<dynamic>> Function() request) async {
    try {
      await request();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<RegisterResult> register({
    required String email,
    required String password,
  }) => _call(
    () => dio.post(
      '/api/v1/auth/register',
      data: {'email': email, 'password': password},
    ),
    RegisterResult.fromJson,
  );
  Future<VerifyEmailResult> verifyEmail({
    required String userId,
    required String code,
  }) => _call(
    () => dio.post(
      '/api/v1/auth/verify-email',
      data: {'userId': userId, 'code': code},
    ),
    VerifyEmailResult.fromJson,
  );
  Future<ResendVerificationResult> resendVerification(String userId) => _call(
    () =>
        dio.post('/api/v1/auth/resend-verification', data: {'userId': userId}),
    ResendVerificationResult.fromJson,
  );
  Future<UsernameAvailabilityResult> checkUsernameAvailability(
    String username,
  ) => _call(
    () => dio.get(
      '/api/v1/auth/usernames/${Uri.encodeComponent(username)}/availability',
    ),
    UsernameAvailabilityResult.fromJson,
  );
  Future<CompleteProfileResult> completeProfile({
    required String profileCompletionToken,
    required String username,
    required String displayName,
    String? bio,
    String? avatarStorageKey,
  }) => _call(
    () => dio.post(
      '/api/v1/auth/complete-profile',
      data: {
        'profileCompletionToken': profileCompletionToken,
        'username': username,
        'displayName': displayName,
        'bio': bio,
        'avatarStorageKey': avatarStorageKey,
      },
    ),
    CompleteProfileResult.fromJson,
  );
  Future<LoginResult> login({
    required String email,
    required String password,
    String? deviceName,
  }) => _call(
    () => dio.post(
      '/api/v1/auth/login',
      data: {'email': email, 'password': password},
      options: Options(
        headers: deviceName == null ? null : {'X-Device-Name': deviceName},
      ),
    ),
    LoginResult.fromJson,
  );
  Future<RefreshTokenResponse> refreshToken(String refreshToken) => _call(
    () => refreshDio.post(
      '/api/v1/auth/refresh',
      data: {'refreshToken': refreshToken},
    ),
    RefreshTokenResponse.fromJson,
  );
  Future<void> logout(String refreshToken) => _empty(
    () =>
        dio.post('/api/v1/auth/logout', data: {'refreshToken': refreshToken}),
  );
  Future<ForgotPasswordResult> forgotPassword(String email) => _call(
    () => dio.post('/api/v1/auth/forgot-password', data: {'email': email}),
    ForgotPasswordResult.fromJson,
  );
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) => _empty(
    () => dio.post(
      '/api/v1/auth/reset-password',
      data: {'email': email, 'code': code, 'newPassword': newPassword},
    ),
  );
  Future<void> changePassword({required String currentPassword, required String newPassword}) => _empty(
    () => dio.post('/api/v1/me/change-password', data: {'currentPassword': currentPassword, 'newPassword': newPassword}),
  );
  Future<CurrentUser> getCurrentUser() =>
      _call(() => dio.get('/api/v1/me'), CurrentUser.fromJson);
}
