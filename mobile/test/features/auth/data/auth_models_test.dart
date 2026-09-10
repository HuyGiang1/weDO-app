import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/auth/data/auth_failure.dart';
import 'package:mobile/features/auth/data/models/auth_models.dart';

void main() {
  test('maps both documented login branches safely', () {
    final authenticated = LoginResult.fromJson({
      'userId': 'user-1',
      'status': 'ACTIVE',
      'nextStep': 'AUTHENTICATED',
      'accessToken': 'access',
      'refreshToken': 'refresh',
      'tokenType': 'Bearer',
      'accessTokenExpiresAt': '2026-01-01T00:00:00Z',
      'user': {
        'id': 'user-1',
        'email': 'u@example.test',
        'username': 'user',
        'displayName': 'User',
      },
    });
    final incomplete = LoginResult.fromJson({
      'userId': 'user-1',
      'status': 'ACTIVE',
      'nextStep': 'COMPLETE_PROFILE',
      'profileCompletionToken': 'onboarding',
    });
    expect(authenticated, isA<AuthenticatedSession>());
    expect(incomplete, isA<ProfileCompletionRequired>());
  });

  test('missing authenticated fields fail parsing rather than yielding a partial session', () {
    expect(
      () => LoginResult.fromJson({
        'userId': 'id',
        'status': 'ACTIVE',
        'nextStep': 'AUTHENTICATED',
      }),
      throwsFormatException,
    );
  });

  test('maps backend and transport errors to safe auth failures', () {
    expect(
      AuthFailure.fromApi(const ApiException(code: 'AUTH_INVALID_CREDENTIALS'))
          .type,
      AuthFailureType.invalidCredentials,
    );
    expect(
      AuthFailure.fromApi(
        const ApiException(transportFailure: ApiTransportFailure.timeout),
      ).type,
      AuthFailureType.timeout,
    );
  });

  test('maps every public auth error code and unknown values', () {
    const codes = <String, AuthFailureType>{
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
    };
    for (final entry in codes.entries) {
      expect(
        AuthFailure.fromApi(ApiException(code: entry.key)).type,
        entry.value,
      );
    }
    expect(
      AuthFailure.fromApi(const ApiException(code: 'UNKNOWN')).type,
      AuthFailureType.unexpected,
    );
    expect(
      AuthFailure.fromApi(
        const ApiException(transportFailure: ApiTransportFailure.network),
      ).type,
      AuthFailureType.network,
    );
  });
}
