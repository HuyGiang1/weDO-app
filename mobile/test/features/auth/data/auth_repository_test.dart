import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/access_token_holder.dart';
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
}

class FakeApi extends AuthApi {
  FakeApi() : super(Dio());
  String? email, password, code, username, profileToken, logoutToken;
  bool incomplete = false, failLogout = false;
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
