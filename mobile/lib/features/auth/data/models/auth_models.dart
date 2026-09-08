class RegisterResult {
  final String userId, email, status, nextStep;
  const RegisterResult({
    required this.userId,
    required this.email,
    required this.status,
    required this.nextStep,
  });
  factory RegisterResult.fromJson(Map<String, dynamic> j) => RegisterResult(
    userId: _string(j, 'userId'),
    email: _string(j, 'email'),
    status: _string(j, 'status'),
    nextStep: _string(j, 'nextStep'),
  );
}

class VerifyEmailResult {
  final String userId, status, nextStep, profileCompletionToken;
  final DateTime emailVerifiedAt;
  const VerifyEmailResult({
    required this.userId,
    required this.status,
    required this.emailVerifiedAt,
    required this.nextStep,
    required this.profileCompletionToken,
  });
  factory VerifyEmailResult.fromJson(Map<String, dynamic> j) =>
      VerifyEmailResult(
        userId: _string(j, 'userId'),
        status: _string(j, 'status'),
        emailVerifiedAt: _date(j, 'emailVerifiedAt'),
        nextStep: _string(j, 'nextStep'),
        profileCompletionToken: _string(j, 'profileCompletionToken'),
      );
}

class ResendVerificationResult {
  final String userId;
  final int cooldownSeconds;
  const ResendVerificationResult({
    required this.userId,
    required this.cooldownSeconds,
  });
  factory ResendVerificationResult.fromJson(Map<String, dynamic> j) =>
      ResendVerificationResult(
        userId: _string(j, 'userId'),
        cooldownSeconds: _int(j, 'cooldownSeconds'),
      );
}

class UsernameAvailabilityResult {
  final String username;
  final bool available;
  const UsernameAvailabilityResult({
    required this.username,
    required this.available,
  });
  factory UsernameAvailabilityResult.fromJson(Map<String, dynamic> j) =>
      UsernameAvailabilityResult(
        username: _string(j, 'username'),
        available: _bool(j, 'available'),
      );
}

class CompleteProfileResult {
  final String userId, username, displayName, status, nextStep;
  const CompleteProfileResult({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.status,
    required this.nextStep,
  });
  factory CompleteProfileResult.fromJson(Map<String, dynamic> j) =>
      CompleteProfileResult(
        userId: _string(j, 'userId'),
        username: _string(j, 'username'),
        displayName: _string(j, 'displayName'),
        status: _string(j, 'status'),
        nextStep: _string(j, 'nextStep'),
      );
}

class UserSummary {
  final String id, email, username, displayName;
  final String? avatarStorageKey;
  const UserSummary({
    required this.id,
    required this.email,
    required this.username,
    required this.displayName,
    this.avatarStorageKey,
  });
  factory UserSummary.fromJson(Map<String, dynamic> j) => UserSummary(
    id: _string(j, 'id'),
    email: _string(j, 'email'),
    username: _string(j, 'username'),
    displayName: _string(j, 'displayName'),
    avatarStorageKey: j['avatarStorageKey'] as String?,
  );
}

sealed class LoginResult {
  const LoginResult();
  factory LoginResult.fromJson(Map<String, dynamic> j) {
    final step = _string(j, 'nextStep');
    if (step == 'AUTHENTICATED') {
      return AuthenticatedSession(
        userId: _string(j, 'userId'),
        status: _string(j, 'status'),
        accessToken: _string(j, 'accessToken'),
        refreshToken: _string(j, 'refreshToken'),
        tokenType: _string(j, 'tokenType'),
        accessTokenExpiresAt: _date(j, 'accessTokenExpiresAt'),
        user: UserSummary.fromJson(_map(j, 'user')),
      );
    }
    if (step == 'COMPLETE_PROFILE') {
      return ProfileCompletionRequired(
        userId: _string(j, 'userId'),
        status: _string(j, 'status'),
        profileCompletionToken: _string(j, 'profileCompletionToken'),
      );
    }
    throw FormatException('Unsupported login nextStep: $step');
  }
}

class AuthenticatedSession extends LoginResult {
  final String userId, status, accessToken, refreshToken, tokenType;
  final DateTime accessTokenExpiresAt;
  final UserSummary user;
  const AuthenticatedSession({
    required this.userId,
    required this.status,
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.accessTokenExpiresAt,
    required this.user,
  });
}

class ProfileCompletionRequired extends LoginResult {
  final String userId, status, profileCompletionToken;
  const ProfileCompletionRequired({
    required this.userId,
    required this.status,
    required this.profileCompletionToken,
  });
}

class ForgotPasswordResult {
  final String message;
  const ForgotPasswordResult(this.message);
  factory ForgotPasswordResult.fromJson(Map<String, dynamic> j) =>
      ForgotPasswordResult(_string(j, 'message'));
}

class CurrentUser {
  final String id, email, status;
  final String? username, phone, displayName, avatarStorageKey, bio;
  final bool emailVerified;
  const CurrentUser({
    required this.id,
    required this.email,
    required this.status,
    required this.emailVerified,
    this.username,
    this.phone,
    this.displayName,
    this.avatarStorageKey,
    this.bio,
  });
  factory CurrentUser.fromJson(Map<String, dynamic> j) => CurrentUser(
    id: _string(j, 'id'),
    email: _string(j, 'email'),
    status: _string(j, 'status'),
    emailVerified: _bool(j, 'emailVerified'),
    username: j['username'] as String?,
    phone: j['phone'] as String?,
    displayName: j['displayName'] as String?,
    avatarStorageKey: j['avatarStorageKey'] as String?,
    bio: j['bio'] as String?,
  );
}

String _string(Map<String, dynamic> j, String k) {
  final v = j[k];
  if (v is String && v.isNotEmpty) {
    return v;
  }
  throw FormatException('Missing $k');
}

int _int(Map<String, dynamic> j, String k) {
  final v = j[k];
  if (v is int) return v;
  if (v is num) return v.toInt();
  throw FormatException('Missing $k');
}

bool _bool(Map<String, dynamic> j, String k) {
  final v = j[k];
  if (v is bool) {
    return v;
  }
  throw FormatException('Missing $k');
}

DateTime _date(Map<String, dynamic> j, String k) {
  final v = _string(j, k);
  final d = DateTime.tryParse(v);
  if (d == null) throw FormatException('Invalid $k');
  return d;
}

Map<String, dynamic> _map(Map<String, dynamic> j, String k) {
  final v = j[k];
  if (v is Map) return Map<String, dynamic>.from(v);
  throw FormatException('Missing $k');
}
