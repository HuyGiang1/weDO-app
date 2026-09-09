import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/access_token_holder.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/core/storage/secure_key_value_store.dart';
import 'package:mobile/core/storage/secure_storage_service.dart';
import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_failure.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';
import 'package:mobile/features/auth/data/models/auth_models.dart';

void main() {
  late FakeApi api;
  late MemoryStore store;
  late AccessTokenHolder holder;
  late AuthRepository repo;
  setUp(() {
    api = FakeApi();
    store = MemoryStore();
    holder = AccessTokenHolder();
    repo = AuthRepository(
      api: api,
      storage: SecureStorageService(store: store),
      accessTokenHolder: holder,
    );
  });
  test('normalizes email, preserves password/code, and never persists onboarding tokens', () async {
    await repo.register(email: ' Test@Example.COM ', password: ' raw ');
    await repo.verifyEmail(userId: 'u', code: '001234');
    await repo.checkUsernameAvailability('Name ');
    await repo.completeProfile(
      profileCompletionToken: 'pct',
      username: 'Name',
      displayName: 'N',
      bio: null,
    );
    expect(api.email, 'test@example.com');
    expect(api.password, ' raw ');
    expect(api.code, '001234');
    expect(api.username, 'name ');
    expect(api.profileToken, 'pct');
    expect(store.values, isEmpty);
  });
  test('authenticated login persists both tokens and storage failure yields typed failure', () async {
    final result = await repo.login(email: ' A@B.C ', password: ' raw ');
    expect(result, isA<AuthenticatedSession>());
    expect(store.values[SecureStorageService.accessTokenKey], 'access');
    expect(store.values[SecureStorageService.refreshTokenKey], 'refresh');
    expect(holder.currentAccessToken, 'access');
    store.fail = true;
    await expectLater(
      repo.login(email: 'a@b.c', password: 'raw'),
      throwsA(isA<AuthException>()),
    );
    expect(holder.currentAccessToken, isNull);
  });
  test('complete-profile login and every logout branch avoid stale local credentials', () async {
    api.incomplete = true;
    final result = await repo.login(email: 'a@b.c', password: 'raw');
    expect(result, isA<ProfileCompletionRequired>());
    expect(store.values, isEmpty);
    expect(holder.currentAccessToken, isNull);
    store.values[SecureStorageService.refreshTokenKey] = 'refresh';
    holder.setAccessToken('access');
    expect((await repo.logout()).remoteRevocationSucceeded, isTrue);
    expect(api.logoutToken, 'refresh');
    expect(store.values, isEmpty);
    expect(holder.currentAccessToken, isNull);
    store.values[SecureStorageService.refreshTokenKey] = 'refresh';
    holder.setAccessToken('access');
    api.failLogout = true;
    expect((await repo.logout()).remoteRevocationSucceeded, isFalse);
    expect(store.values, isEmpty);
    expect(holder.currentAccessToken, isNull);
    api.failLogout = false;
    api.logoutToken = null;
    holder.setAccessToken('access');
    await repo.logout();
    expect(api.logoutToken, isNull);
    expect(holder.currentAccessToken, isNull);
  });
  test('clearLocalSession clears local credentials without remote logout', () async {
    store.values[SecureStorageService.accessTokenKey] = 'access';
    store.values[SecureStorageService.refreshTokenKey] = 'refresh';
    holder.setAccessToken('access');

    await repo.clearLocalSession();

    expect(store.values, isEmpty);
    expect(holder.currentAccessToken, isNull);
    expect(api.logoutToken, isNull);
  });
  test('clearLocalSession clears the in-memory bearer when storage clearing fails', () async {
    store.values[SecureStorageService.accessTokenKey] = 'access';
    store.values[SecureStorageService.refreshTokenKey] = 'refresh';
    store.failDeletes = true;
    holder.setAccessToken('access');

    await expectLater(repo.clearLocalSession(), throwsA(isA<AuthException>()));

    expect(holder.currentAccessToken, isNull);
    expect(api.logoutToken, isNull);
  });

  group('AuthRepository.refreshSession', () {
    test('success path: reads old refresh token, calls API, atomically persists new pair, updates holder', () async {
      store.values[SecureStorageService.accessTokenKey] = 'access-old';
      store.values[SecureStorageService.refreshTokenKey] = 'refresh-old';
      holder.setAccessToken('access-old');

      await repo.refreshSession();

      expect(api.refreshTokenArg, 'refresh-old');
      expect(store.values[SecureStorageService.accessTokenKey], 'new-access');
      expect(store.values[SecureStorageService.refreshTokenKey], 'new-refresh');
      expect(holder.currentAccessToken, 'new-access');
    });

    test('missing or blank refresh token throws noRefreshableSession with zero API calls', () async {
      // Null token
      await expectLater(
        repo.refreshSession(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.failure.type,
            'type',
            AuthFailureType.noRefreshableSession,
          ),
        ),
      );
      expect(api.refreshTokenArg, isNull);

      // Blank token
      store.values[SecureStorageService.refreshTokenKey] = '   ';
      await expectLater(
        repo.refreshSession(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.failure.type,
            'type',
            AuthFailureType.noRefreshableSession,
          ),
        ),
      );
      expect(api.refreshTokenArg, isNull);
    });

    test('storage write failure after rotation clears holder, evicts session, throws refreshSessionUnrecoverable', () async {
      store.values[SecureStorageService.accessTokenKey] = 'access-old';
      store.values[SecureStorageService.refreshTokenKey] = 'refresh-old';
      holder.setAccessToken('access-old');
      store.fail = true;

      await expectLater(
        repo.refreshSession(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.failure.type,
            'type',
            AuthFailureType.refreshSessionUnrecoverable,
          ),
        ),
      );

      // New access token was not applied, RAM cleared, storage evicted
      expect(holder.currentAccessToken, isNull);
      expect(store.values, isEmpty);
    });

    test('malformed success response clears holder, evicts session, throws refreshSessionUnrecoverable', () async {
      store.values[SecureStorageService.accessTokenKey] = 'access-old';
      store.values[SecureStorageService.refreshTokenKey] = 'refresh-old';
      holder.setAccessToken('access-old');
      api.malformedRefresh = true;

      await expectLater(
        repo.refreshSession(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.failure.type,
            'type',
            AuthFailureType.refreshSessionUnrecoverable,
          ),
        ),
      );

      expect(holder.currentAccessToken, isNull);
      expect(store.values, isEmpty);
    });

    test('wrong JSON type or TypeError during refresh clears holder, evicts session, throws refreshSessionUnrecoverable', () async {
      store.values[SecureStorageService.accessTokenKey] = 'access-old';
      store.values[SecureStorageService.refreshTokenKey] = 'refresh-old';
      holder.setAccessToken('access-old');
      api.throwTypeErrorOnRefresh = true;

      await expectLater(
        repo.refreshSession(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.failure.type,
            'type',
            AuthFailureType.refreshSessionUnrecoverable,
          ),
        ),
      );

      expect(holder.currentAccessToken, isNull);
      expect(store.values, isEmpty);
    });

    test('remote failure before rotation maps typed failure without clearing local session in this slice', () async {
      store.values[SecureStorageService.accessTokenKey] = 'access-old';
      store.values[SecureStorageService.refreshTokenKey] = 'refresh-old';
      holder.setAccessToken('access-old');

      api.failRefreshWith = const ApiException(
        statusCode: 401,
        code: 'REFRESH_TOKEN_INVALID',
      );

      await expectLater(
        repo.refreshSession(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.failure.type,
            'type',
            AuthFailureType.refreshTokenInvalid,
          ),
        ),
      );

      // In M2.15.2, repository does not clear session on remote error prior to M2.15.4
      expect(store.values[SecureStorageService.refreshTokenKey], 'refresh-old');

      // Account suspended
      api.failRefreshWith = const ApiException(
        statusCode: 403,
        code: 'ACCOUNT_SUSPENDED',
      );
      await expectLater(
        repo.refreshSession(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.failure.type,
            'type',
            AuthFailureType.accountSuspended,
          ),
        ),
      );
    });
  });
}

class FakeApi extends AuthApi {
  FakeApi() : super(Dio(), refreshDio: Dio());
  String? email, password, code, username, profileToken, logoutToken, refreshTokenArg;
  bool incomplete = false, failLogout = false, malformedRefresh = false, throwTypeErrorOnRefresh = false;
  ApiException? failRefreshWith;

  @override
  Future<RefreshTokenResponse> refreshToken(String refreshToken) async {
    refreshTokenArg = refreshToken;
    if (failRefreshWith != null) throw failRefreshWith!;
    if (throwTypeErrorOnRefresh) {
      throw TypeError();
    }
    if (malformedRefresh) {
      throw const FormatException('malformed response');
    }
    return RefreshTokenResponse(
      accessToken: 'new-access',
      refreshToken: 'new-refresh',
      tokenType: 'Bearer',
      accessTokenExpiresAt: DateTime(2026, 6, 1),
      refreshTokenExpiresAt: DateTime(2026, 6, 8),
    );
  }
  @override
  Future<RegisterResult> register({
    required String email,
    required String password,
  }) async {
    this.email = email;
    this.password = password;
    return const RegisterResult(
      userId: 'u',
      email: 'e',
      status: 's',
      nextStep: 'n',
    );
  }

  @override
  Future<VerifyEmailResult> verifyEmail({
    required String userId,
    required String code,
  }) async {
    this.code = code;
    return VerifyEmailResult(
      userId: 'u',
      status: 's',
      emailVerifiedAt: DateTime(2026),
      nextStep: 'n',
      profileCompletionToken: 'pct',
    );
  }

  @override
  Future<UsernameAvailabilityResult> checkUsernameAvailability(String u) async {
    username = u;
    return UsernameAvailabilityResult(username: u, available: true);
  }

  @override
  Future<CompleteProfileResult> completeProfile({
    required String profileCompletionToken,
    required String username,
    required String displayName,
    String? bio,
    String? avatarStorageKey,
  }) async {
    profileToken = profileCompletionToken;
    return const CompleteProfileResult(
      userId: 'u',
      username: 'n',
      displayName: 'n',
      status: 's',
      nextStep: 'n',
    );
  }

  @override
  Future<LoginResult> login({
    required String email,
    required String password,
    String? deviceName,
  }) async {
    this.email = email;
    this.password = password;
    return incomplete
        ? const ProfileCompletionRequired(
            userId: 'u',
            status: 's',
            profileCompletionToken: 'pct',
          )
        : AuthenticatedSession(
            userId: 'u',
            status: 's',
            accessToken: 'access',
            refreshToken: 'refresh',
            tokenType: 'Bearer',
            accessTokenExpiresAt: DateTime(2026),
            user: const UserSummary(
              id: 'u',
              email: 'e',
              username: 'n',
              displayName: 'n',
            ),
          );
  }

  @override
  Future<void> logout(String token) async {
    logoutToken = token;
    if (failLogout) throw StateError('x');
  }
}

class MemoryStore implements SecureKeyValueStore {
  final values = <String, String>{};
  bool fail = false, failDeletes = false;
  @override
  Future<void> delete(String k) async {
    if (failDeletes) throw StateError('x');
    values.remove(k);
  }

  @override
  Future<String?> read(String k) async => values[k];
  @override
  Future<void> write({required String key, required String value}) async {
    if (fail) throw StateError('x');
    values[key] = value;
  }
}
