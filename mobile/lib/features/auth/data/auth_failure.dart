import '../../../core/network/api_exception.dart';

enum AuthFailureType {
  emailAlreadyExists,
  verificationCodeInvalid,
  verificationCodeExpired,
  verificationAttemptsExceeded,
  resendCooldownActive,
  usernameUnavailable,
  invalidCredentials,
  emailNotVerified,
  accountLocked,
  accountSuspended,
  accountDeactivated,
  profileAlreadyCompleted,
  passwordResetCodeInvalid,
  refreshTokenInvalid,
  noRefreshableSession,
  refreshSessionUnrecoverable,
  refreshSessionSuperseded,
  network,
  timeout,
  unexpected,
}

class AuthFailure {
  final AuthFailureType type;
  final String? backendCode;
  final String? backendMessage;
  final Map<String, String> fieldErrors;

  const AuthFailure(
    this.type, {
    this.backendCode,
    this.backendMessage,
    this.fieldErrors = const {},
  });

  factory AuthFailure.fromApi(ApiException exception) {
    const types = <String, AuthFailureType>{
      'EMAIL_ALREADY_EXISTS': AuthFailureType.emailAlreadyExists,
      'VERIFICATION_CODE_INVALID': AuthFailureType.verificationCodeInvalid,
      'VERIFICATION_CODE_EXPIRED': AuthFailureType.verificationCodeExpired,
      'VERIFICATION_ATTEMPTS_EXCEEDED':
          AuthFailureType.verificationAttemptsExceeded,
      'RESEND_COOLDOWN_ACTIVE': AuthFailureType.resendCooldownActive,
      'USERNAME_ALREADY_EXISTS': AuthFailureType.usernameUnavailable,
      'AUTH_INVALID_CREDENTIALS': AuthFailureType.invalidCredentials,
      'EMAIL_NOT_VERIFIED': AuthFailureType.emailNotVerified,
      'ACCOUNT_LOCKED': AuthFailureType.accountLocked,
      'ACCOUNT_SUSPENDED': AuthFailureType.accountSuspended,
      'ACCOUNT_DEACTIVATED': AuthFailureType.accountDeactivated,
      'PROFILE_ALREADY_COMPLETED': AuthFailureType.profileAlreadyCompleted,
      'PASSWORD_RESET_CODE_INVALID': AuthFailureType.passwordResetCodeInvalid,
      'REFRESH_TOKEN_INVALID': AuthFailureType.refreshTokenInvalid,
    };
    final type =
        types[exception.code] ??
        switch (exception.transportFailure) {
          ApiTransportFailure.network => AuthFailureType.network,
          ApiTransportFailure.timeout => AuthFailureType.timeout,
          _ => AuthFailureType.unexpected,
        };
    return AuthFailure(
      type,
      backendCode: exception.code,
      backendMessage: exception.message,
      fieldErrors: exception.fieldErrors,
    );
  }
}

class AuthException implements Exception {
  final AuthFailure failure;
  const AuthException(this.failure);
}
