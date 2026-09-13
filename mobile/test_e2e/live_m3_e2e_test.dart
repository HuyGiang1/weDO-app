// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/access_token_holder.dart';
import 'package:mobile/core/network/api_config.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/core/network/auth_interceptor.dart';
import 'package:mobile/core/network/dio_client.dart';
import 'package:mobile/core/storage/secure_key_value_store.dart';
import 'package:mobile/core/storage/secure_storage_service.dart';
import 'package:mobile/features/auth/application/auth_session_controller.dart';
import 'package:mobile/features/auth/application/auth_session_invalidator.dart';
import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_failure.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';
import 'package:mobile/features/auth/data/models/auth_models.dart';
import 'package:mobile/features/profile/data/profile_api.dart';
import 'package:mobile/features/profile/data/profile_models.dart';
import 'package:mobile/features/profile/data/profile_repository.dart';
import 'package:mobile/features/privacy/data/privacy_api.dart';
import 'package:mobile/features/privacy/data/privacy_models.dart';
import 'package:mobile/features/privacy/data/privacy_repository.dart';
import 'package:mobile/features/qr/data/personal_qr_api.dart';
import 'package:mobile/features/qr/data/personal_qr_repository.dart';

class _MemoryStore implements SecureKeyValueStore {
  final Map<String, String> values = {};
  @override Future<String?> read(String key) async => values[key];
  @override Future<void> write({required String key, required String value}) async => values[key] = value;
  @override Future<void> delete(String key) async => values.remove(key);
}

class _LiveClient {
  final AccessTokenHolder holder;
  final SecureStorageService storage;
  final AuthApi authApi;
  final AuthRepository auth;
  final AuthSessionController session;
  final ProfileRepository profile;
  final PrivacyRepository privacy;
  final PersonalQrRepository qr;
  final Dio dio;
  final Dio refreshDio;

  _LiveClient._(this.holder, this.storage, this.authApi, this.auth, this.session, this.profile, this.privacy, this.qr, this.dio, this.refreshDio);

  factory _LiveClient.create(ApiConfig config) {
    final holder = AccessTokenHolder();
    final storage = SecureStorageService(store: _MemoryStore());
    final client = DioClient(apiConfig: config);
    final raw = DioClient.raw(apiConfig: config);
    final authApi = AuthApi(client.dio, refreshDio: raw.dio);
    final auth = AuthRepository(api: authApi, storage: storage, accessTokenHolder: holder);
    final session = AuthSessionController(storage: storage, accessTokenHolder: holder, repository: auth);
    final invalidator = AuthSessionInvalidator(repository: auth, sessionController: session);
    client.attachAuthInterceptor(AuthInterceptor(
      accessTokenHolder: holder,
      refreshSession: ({required int expectedRevision}) async {
        try { return await auth.refreshSession(expectedRevision: expectedRevision); }
        on AuthException catch (error) { await invalidator.handleRefreshFailure(failure: error.failure, expectedRevision: expectedRevision); rethrow; }
      },
      onAccessTokenInvalid: invalidator.handleAccessTokenInvalid,
      dio: client.dio,
    ));
    return _LiveClient._(holder, storage, authApi, auth, session, ProfileRepository(api: ProfileApi(client.dio)), PrivacyRepository(api: PrivacyApi(client.dio)), PersonalQrRepository(api: PersonalQrApi(client.dio)), client.dio, raw.dio);
  }

  void dispose() {
    session.dispose();
    dio.close(force: true);
    refreshDio.close(force: true);
  }
}

Future<String> _otp(String userId) async {
  final directory = await Directory.systemTemp.createTemp('wedo_m3_otp_');
  final output = File('${directory.path}${Platform.pathSeparator}otp.txt');
  try {
    final backend = Directory('../backend').existsSync() ? Directory('../backend') : Directory('backend');
    final executable = Platform.isWindows ? File('${backend.path}\\mvnw.cmd').absolute.path : File('${backend.path}/mvnw').absolute.path;
    final result = await Process.run(executable, ['-Dtest=OtpResolverTest', '-Dwedo.e2e.user-id=$userId', '-Dwedo.e2e.otp-output-file=${output.absolute.path}', 'test'], workingDirectory: backend.absolute.path, runInShell: Platform.isWindows).timeout(const Duration(minutes: 1), onTimeout: () => throw TimeoutException('OTP resolver timed out'));
    if (result.exitCode != 0 || !output.existsSync()) throw StateError('OTP resolver failed; inspect backend local profile output.');
    final value = (await output.readAsString()).trim();
    if (!RegExp(r'^\d{6}$').hasMatch(value)) throw StateError('OTP resolver returned an invalid code.');
    return value;
  } finally { if (directory.existsSync()) await directory.delete(recursive: true).timeout(const Duration(seconds: 10)); }
}

Future<String> _registerActive(_LiveClient client, String suffix, String password) async {
  final registration = await client.auth.register(email: 'm3_$suffix@example.com', password: password);
  final verification = await client.auth.verifyEmail(userId: registration.userId, code: await _otp(registration.userId));
  await client.auth.completeProfile(profileCompletionToken: verification.profileCompletionToken, username: 'm3_${suffix.replaceAll('-', '')}', displayName: 'M3 $suffix', bio: 'M3 live E2E');
  final login = await client.auth.login(email: 'm3_$suffix@example.com', password: password) as AuthenticatedSession;
  expect(login.userId, registration.userId);
  expect(client.holder.currentAccessToken, isNotNull);
  client.session.markAuthenticated();
  expect(client.session.status, AuthSessionStatus.authenticated);
  return registration.userId;
}

void main() {
  test('M3.8 live E2E uses real Flutter networking, Spring Security, and PostgreSQL', () async {
    final config = ApiConfig(baseUrl: const String.fromEnvironment('WEDO_API_BASE_URL', defaultValue: 'http://127.0.0.1:8080'));
    try { expect((await Dio(BaseOptions(baseUrl: config.baseUrl)).get('/api/v1/health')).statusCode, 200); }
    catch (error) { throw TestFailure('Live backend unavailable at ${config.baseUrl}: $error'); }
    const oldPassword = 'Password123!';
    const newPassword = 'NewPassword123!';
    final suffix = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final a = _LiveClient.create(config);
    final b = _LiveClient.create(config);
    try {
    final userAId = await _registerActive(a, '${suffix}a', oldPassword).timeout(const Duration(minutes: 1));
    print('[M3-E2E] login A complete');
    final userBId = await _registerActive(b, '${suffix}b', oldPassword).timeout(const Duration(minutes: 1));

    final initial = await a.auth.getCurrentUser();
    expect(initial.id, userAId);
    final updated = await a.profile.updateProfile(const UpdateProfileRequest(displayName: 'M3 Updated', bio: 'Persisted profile bio'));
    expect(updated.displayName, 'M3 Updated');
    final afterProfile = await a.auth.getCurrentUser();
    expect(afterProfile.bio, 'Persisted profile bio');
    print('[M3-E2E] profile complete');

  final username = 'm3_live_$suffix';
    final afterUsername = await a.profile.updateUsername(UpdateUsernameRequest(username: username.toUpperCase()));
    expect(afterUsername.username, username);
    expect((await a.auth.getCurrentUser()).username, username);
    print('[M3-E2E] username complete');

    final initialPrivacy = await a.privacy.getPrivacySettings();
    expect(initialPrivacy.discoverByQr, isTrue);
    final savedPrivacy = await a.privacy.updatePrivacySettings(const UpdatePrivacySettingsRequest(discoverByQr: false, showLastSeen: false));
    expect(savedPrivacy.discoverByQr, isFalse);
    expect((await a.privacy.getPrivacySettings()).showLastSeen, isFalse);
    await a.privacy.updatePrivacySettings(const UpdatePrivacySettingsRequest(discoverByQr: true));
    print('[M3-E2E] privacy complete');

    final publicResponse = await b.dio.get('/api/v1/users/$userAId');
    expect((publicResponse.data as Map).keys.toSet(), {'id', 'username', 'displayName', 'avatarStorageKey', 'bio'});
    expect(publicResponse.data['id'], userAId);
    expect(userBId, isNot(userAId));
    print('[M3-E2E] public profile complete');

    final personalQr = await a.qr.getPersonalQr();
    expect(personalQr.deepLink, 'wedo://user/$userAId');
    final resolved = await b.dio.post('/api/v1/users/qr/resolve', data: {'deepLink': personalQr.deepLink});
    expect((resolved.data as Map).keys.toSet(), {'id', 'username', 'displayName', 'avatarStorageKey', 'bio'});
    expect(resolved.data['id'], userAId);
    print('[M3-E2E] QR enabled resolve complete');
    await a.privacy.updatePrivacySettings(const UpdatePrivacySettingsRequest(discoverByQr: false));
    try { await b.dio.post('/api/v1/users/qr/resolve', data: {'deepLink': personalQr.deepLink}); fail('QR resolution should be hidden when discoverByQr is false'); }
    on DioException catch (error) { expect(error.response?.statusCode, 404); expect((error.response?.data as Map)['code'], 'RESOURCE_NOT_FOUND'); }
    expect((await a.qr.getPersonalQr()).deepLink, personalQr.deepLink);
    print('[M3-E2E] QR disabled resolve complete');

    final oldRefresh = await a.storage.readRefreshToken();
    await a.auth.changePassword(currentPassword: oldPassword, newPassword: newPassword);
    await a.session.endSessionAfterPasswordChange();
    expect(a.holder.currentAccessToken, isNull);
    expect(await a.storage.readAccessToken(), isNull);
    expect(a.session.status, AuthSessionStatus.unauthenticated);
    print('[M3-E2E] password change complete');
    try { await a.authApi.refreshToken(oldRefresh!); fail('Pre-change refresh token must be revoked'); }
    on ApiException catch (error) { expect(error.statusCode, 401); expect(error.code, 'REFRESH_TOKEN_INVALID'); }
    print('[M3-E2E] old refresh rejected');
    try { await a.auth.login(email: 'm3_${suffix}a@example.com', password: oldPassword); fail('Old password must fail'); }
    on AuthException catch (_) {}
    print('[M3-E2E] old password rejected');
    expect(await a.auth.login(email: 'm3_${suffix}a@example.com', password: newPassword), isA<AuthenticatedSession>());
    print('[M3-E2E] new password accepted');
    print('[M3-E2E] assertions complete');
    } finally {
      print('[M3-E2E] teardown begin');
      a.dispose();
      b.dispose();
      print('[M3-E2E] teardown complete');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
