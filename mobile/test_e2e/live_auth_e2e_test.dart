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

/// Minimal in-memory implementation of [SecureKeyValueStore] for headless
/// live client-backend E2E testing without native platform Keychain/Keystore bindings.
class InMemorySecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
}

/// Resolves the 6-digit email verification OTP from the live local PostgreSQL
/// database using the test-scoped [OtpResolverTest] helper.
///
/// Communicates through a temporary IPC file that is deleted immediately
/// upon reading. Never logs or prints the OTP.
Future<String> _resolveVerificationOtp({required String userId}) async {
  final tempDir = await Directory.systemTemp.createTemp('wedo_otp_');
  final tempFile = File('${tempDir.path}${Platform.pathSeparator}otp.txt');

  try {
    Directory backendDir = Directory('../backend');
    if (!backendDir.existsSync()) {
      backendDir = Directory('backend');
    }
    if (!backendDir.existsSync()) {
      throw StateError(
        'Cannot locate backend directory from ${Directory.current.path}',
      );
    }

    final isWindows = Platform.isWindows;
    final mvnExecutable = isWindows
        ? File('${backendDir.path}\\mvnw.cmd').absolute.path
        : File('${backendDir.path}/mvnw').absolute.path;

    final args = [
      '-Dtest=OtpResolverTest',
      '-Dwedo.e2e.user-id=$userId',
      '-Dwedo.e2e.otp-output-file=${tempFile.absolute.path}',
      'test',
    ];

    final result = await Process.run(
      mvnExecutable,
      args,
      workingDirectory: backendDir.absolute.path,
      runInShell: isWindows,
    );

    if (result.exitCode != 0) {
      throw StateError(
        'OtpResolverTest failed with exit code ${result.exitCode}.\n'
        'Check that local PostgreSQL is running and auth_tokens record exists.\n'
        'Process stdout:\n${result.stdout}\n'
        'Process stderr:\n${result.stderr}',
      );
    }

    if (!tempFile.existsSync()) {
      throw StateError(
        'OtpResolverTest finished but output file was not created: ${tempFile.path}',
      );
    }

    final otp = (await tempFile.readAsString()).trim();
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      throw StateError('Resolved OTP is not 6 digits (length: ${otp.length})');
    }

    return otp;
  } finally {
    try {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {
      // Best-effort temp cleanup
    }
  }
}

void main() {
  test(
    'M2.16 Live Auth E2E: Register -> Verify -> Profile -> Login -> Protected -> Auto-Refresh -> Logout',
    () async {
      // 1. Client Composition with real Dio networking & in-memory test storage
      final apiConfig = ApiConfig(
        baseUrl: const String.fromEnvironment(
          'WEDO_API_BASE_URL',
          defaultValue: 'http://127.0.0.1:8080',
        ),
      );

      // Pre-flight check: ensure live backend is responding
      try {
        final preflightDio = Dio(
          BaseOptions(
            baseUrl: apiConfig.baseUrl,
            connectTimeout: const Duration(seconds: 3),
            receiveTimeout: const Duration(seconds: 3),
          ),
        );
        final healthRes = await preflightDio.get<dynamic>('/api/v1/health');
        if (healthRes.statusCode != 200) {
          throw TestFailure(
            'Backend responded with status ${healthRes.statusCode} on /api/v1/health. Expected 200.',
          );
        }
      } catch (e) {
        if (e is TestFailure) rethrow;
        throw TestFailure(
          'Cannot connect to live backend at ${apiConfig.baseUrl}.\n'
          'Ensure Spring Boot is running (e.g. WEDO_JWT_ACCESS_TOKEN_TTL=5s ./mvnw spring-boot:run) '
          'and local PostgreSQL is running.\nDetails: $e',
        );
      }

      final holder = AccessTokenHolder();
      final inMemoryStore = InMemorySecureKeyValueStore();
      final storage = SecureStorageService(store: inMemoryStore);

      final dioClient = DioClient(apiConfig: apiConfig);
      final refreshDioClient = DioClient.raw(apiConfig: apiConfig);

      final authApi = AuthApi(
        dioClient.dio,
        refreshDio: refreshDioClient.dio,
      );
      final repository = AuthRepository(
        api: authApi,
        storage: storage,
        accessTokenHolder: holder,
      );
      final sessionController = AuthSessionController(
        storage: storage,
        accessTokenHolder: holder,
        repository: repository,
      );
      final invalidator = AuthSessionInvalidator(
        repository: repository,
        sessionController: sessionController,
      );

      dioClient.attachAuthInterceptor(
        AuthInterceptor(
          accessTokenHolder: holder,
          refreshSession: ({required int expectedRevision}) async {
            try {
              return await repository.refreshSession(
                expectedRevision: expectedRevision,
              );
            } on AuthException catch (error) {
              await invalidator.handleRefreshFailure(
                failure: error.failure,
                expectedRevision: expectedRevision,
              );
              rethrow;
            }
          },
          onAccessTokenInvalid: invalidator.handleAccessTokenInvalid,
          dio: dioClient.dio,
        ),
      );

      // 2. Step 1: Register unique test user
      final ts = DateTime.now().millisecondsSinceEpoch;
      final email = 'e2e_$ts@example.com';
      final username = 'u_${ts.toRadixString(36)}';
      const password = 'Password123!';

      final registerResult = await repository.register(
        email: email,
        password: password,
      );
      expect(registerResult.userId, isNotEmpty);
      expect(registerResult.email, equals(email));
      expect(registerResult.nextStep, equals('VERIFY_EMAIL'));
      final userId = registerResult.userId;

      // 3. Step 2: Resolve verification OTP and verify email
      final otp = await _resolveVerificationOtp(userId: userId);
      expect(otp.length, equals(6));

      final verifyResult = await repository.verifyEmail(
        userId: userId,
        code: otp,
      );
      expect(verifyResult.userId, equals(userId));
      expect(verifyResult.status, equals('ACTIVE'));
      expect(verifyResult.nextStep, equals('COMPLETE_PROFILE'));
      expect(verifyResult.profileCompletionToken, isNotEmpty);
      final profileToken = verifyResult.profileCompletionToken;

      // 4. Step 3: Complete profile (username reservation)
      final completeResult = await repository.completeProfile(
        profileCompletionToken: profileToken,
        username: username,
        displayName: 'E2E Live User',
        bio: 'Automated E2E Verification',
      );
      expect(completeResult.userId, equals(userId));
      expect(completeResult.username, equals(username));
      expect(completeResult.displayName, equals('E2E Live User'));
      expect(completeResult.status, equals('ACTIVE'));
      expect(completeResult.nextStep, equals('LOGIN'));

      // 5. Step 4: Login through real client session logic
      final loginResult = await repository.login(
        email: email,
        password: password,
      );
      expect(loginResult, isA<AuthenticatedSession>());
      final session = loginResult as AuthenticatedSession;
      expect(session.userId, equals(userId));
      expect(session.accessToken, isNotEmpty);
      expect(session.refreshToken, isNotEmpty);
      expect(session.tokenType, equals('Bearer'));

      final a1 = holder.currentAccessToken;
      final r1 = await storage.readRefreshToken();
      final rev1 = holder.revision;

      expect(a1, isNotNull);
      expect(a1, equals(session.accessToken));
      expect(r1, isNotNull);
      expect(r1, equals(session.refreshToken));
      expect(rev1, equals(1));

      // 6. Step 5: Initial protected request with A1
      final initialUser = await repository.getCurrentUser();
      expect(initialUser.id, equals(userId));
      expect(initialUser.username, equals(username));
      expect(holder.revision, equals(rev1)); // Revision unchanged on normal read

      // 7. Step 6: Wait for real access token expiry and assert transparent auto-refresh
      final expiry = session.accessTokenExpiresAt;
      final diff = expiry.difference(DateTime.now());
      if (diff.inMilliseconds > 0) {
        await Future<void>.delayed(
          Duration(milliseconds: diff.inMilliseconds + 800),
        );
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 800));
      }

      // DO NOT call repository.refreshSession() directly.
      // Call standard repository.getCurrentUser() normally.
      final refreshedUser = await repository.getCurrentUser();
      expect(refreshedUser.id, equals(userId));
      expect(refreshedUser.username, equals(username));

      final a2 = holder.currentAccessToken;
      final r2 = await storage.readRefreshToken();
      final rev2 = holder.revision;

      expect(rev2, equals(rev1 + 1));
      expect(a2, isNotNull);
      expect(a2, isNotEmpty);
      expect(a2, isNot(equals(a1)));
      expect(r2, isNotNull);
      expect(r2, isNotEmpty);
      expect(r2, isNot(equals(r1)));

      // 8. Step 7: Logout using rotated R2
      final capturedR2 = r2!;
      await repository.logout();

      expect(holder.currentAccessToken, isNull);
      expect(await storage.readAccessToken(), isNull);
      expect(await storage.readRefreshToken(), isNull);

      // 9. Step 8: Post-logout server revocation proof (isolated raw call with captured R2)
      try {
        await authApi.refreshToken(capturedR2);
        fail('Expected refreshToken with revoked session token to fail');
      } on ApiException catch (e) {
        expect(e.statusCode, equals(401));
        expect(e.code, equals('REFRESH_TOKEN_INVALID'));
      }

      // Confirm local repository state remains unauthenticated
      expect(holder.currentAccessToken, isNull);
      expect(await storage.readAccessToken(), isNull);
      expect(await storage.readRefreshToken(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
