import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/access_token_holder.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/core/storage/secure_key_value_store.dart';
import 'package:mobile/core/storage/secure_storage_service.dart';
import 'package:mobile/features/auth/application/auth_session_controller.dart';
import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';
import 'package:mobile/features/auth/data/models/auth_models.dart';
import 'package:mobile/features/auth/presentation/auth_flow_coordinator.dart';

void main() {
  group('AuthSessionController - Restoration & State', () {
    late TestSecureStore store;
    late SecureStorageService storage;
    late AccessTokenHolder holder;
    late TestApi api;
    late AuthRepository repo;
    late AuthSessionController controller;

    setUp(() {
      store = TestSecureStore();
      storage = SecureStorageService(store: store);
      holder = AccessTokenHolder();
      api = TestApi();
      repo = AuthRepository(
        api: api,
        storage: storage,
        accessTokenHolder: holder,
      );
      controller = AuthSessionController(
        storage: storage,
        accessTokenHolder: holder,
        repository: repo,
      );
    });

    test('initial status is restoring', () {
      expect(controller.status, AuthSessionStatus.restoring);
      expect(controller.isRestoring, isTrue);
      expect(controller.isAuthenticated, isFalse);
    });

    test('both tokens present: populates holder, status authenticated, zero network calls', () async {
      store.values[SecureStorageService.accessTokenKey] = 'valid-access-token';
      store.values[SecureStorageService.refreshTokenKey] = 'valid-refresh-token';

      final status = await controller.restoreSession();

      expect(status, AuthSessionStatus.authenticated);
      expect(controller.status, AuthSessionStatus.authenticated);
      expect(controller.isAuthenticated, isTrue);
      expect(controller.isRestoring, isFalse);
      expect(holder.currentAccessToken, 'valid-access-token');

      // Zero network calls (lazy validation, no /me or /refresh on startup)
      expect(api.networkCalls, isEmpty);
      expect(api.currentUserCalls, 0);
      expect(api.refreshCalls, 0);
    });

    test('no tokens: clears holder, status unauthenticated, zero network calls', () async {
      holder.setAccessToken('old-stale-token');

      final status = await controller.restoreSession();

      expect(status, AuthSessionStatus.unauthenticated);
      expect(controller.status, AuthSessionStatus.unauthenticated);
      expect(controller.isAuthenticated, isFalse);
      expect(holder.currentAccessToken, isNull);
      expect(api.networkCalls, isEmpty);
    });

    test('whitespace tokens: treated as absent, status unauthenticated', () async {
      store.values[SecureStorageService.accessTokenKey] = '   ';
      store.values[SecureStorageService.refreshTokenKey] = '   ';

      final status = await controller.restoreSession();

      expect(status, AuthSessionStatus.unauthenticated);
      expect(holder.currentAccessToken, isNull);
      expect(api.networkCalls, isEmpty);
    });

    test('partial session - refresh only: clears durable storage via repository, status unauthenticated', () async {
      store.values[SecureStorageService.refreshTokenKey] = 'orphaned-refresh-token';
      holder.setAccessToken('stale-ram-token');

      final status = await controller.restoreSession();

      expect(status, AuthSessionStatus.unauthenticated);
      expect(controller.status, AuthSessionStatus.unauthenticated);
      expect(holder.currentAccessToken, isNull);
      expect(store.values[SecureStorageService.refreshTokenKey], isNull);
      expect(store.values[SecureStorageService.accessTokenKey], isNull);
      expect(api.networkCalls, isEmpty);
    });

    test('partial session - access only: clears durable storage via repository, status unauthenticated', () async {
      store.values[SecureStorageService.accessTokenKey] = 'unrotatable-access-token';

      final status = await controller.restoreSession();

      expect(status, AuthSessionStatus.unauthenticated);
      expect(controller.status, AuthSessionStatus.unauthenticated);
      expect(holder.currentAccessToken, isNull);
      expect(store.values[SecureStorageService.accessTokenKey], isNull);
      expect(api.networkCalls, isEmpty);
    });

    test('storage read failure: clears holder, status unauthenticated, does NOT destroy durable storage', () async {
      store.values[SecureStorageService.accessTokenKey] = 'persisted-access';
      store.values[SecureStorageService.refreshTokenKey] = 'persisted-refresh';
      store.failOnRead = true;
      holder.setAccessToken('existing-ram-token');

      final status = await controller.restoreSession();

      expect(status, AuthSessionStatus.unauthenticated);
      expect(controller.status, AuthSessionStatus.unauthenticated);
      expect(holder.currentAccessToken, isNull);

      // Verify durable credentials were NOT wiped merely because read failed
      expect(store.values[SecureStorageService.accessTokenKey], 'persisted-access');
      expect(store.values[SecureStorageService.refreshTokenKey], 'persisted-refresh');
      expect(store.deletedKeys, isEmpty);
      expect(api.networkCalls, isEmpty);
    });

    test('markAuthenticated and markUnauthenticated update status and notify listeners', () {
      final notifications = <AuthSessionStatus>[];
      controller.addListener(() => notifications.add(controller.status));

      controller.markAuthenticated();
      expect(controller.status, AuthSessionStatus.authenticated);

      controller.markUnauthenticated();
      expect(controller.status, AuthSessionStatus.unauthenticated);

      expect(notifications, [
        AuthSessionStatus.authenticated,
        AuthSessionStatus.unauthenticated,
      ]);
    });

    test('security invariants: controller does not store credentials as fields', () {
      // Controller exposes only status, not tokens or secrets
      expect(controller.value, isA<AuthSessionStatus>());
      expect(controller.status, isA<AuthSessionStatus>());
    });
  });

  group('AuthFlowCoordinator & AuthSessionController Integration', () {
    late TestSecureStore store;
    late SecureStorageService storage;
    late AccessTokenHolder holder;
    late TestApi api;
    late AuthRepository repo;
    late AuthSessionController controller;
    late AuthFlowCoordinator coordinator;

    setUp(() {
      store = TestSecureStore();
      storage = SecureStorageService(store: store);
      holder = AccessTokenHolder();
      api = TestApi();
      repo = AuthRepository(
        api: api,
        storage: storage,
        accessTokenHolder: holder,
      );
      controller = AuthSessionController(
        storage: storage,
        accessTokenHolder: holder,
        repository: repo,
        initialStatus: AuthSessionStatus.unauthenticated,
      );
      coordinator = AuthFlowCoordinator(
        repo,
        sessionController: controller,
      );
    });

    testWidgets('authenticated login marks session controller as authenticated', (tester) async {
      api.loginResult = AuthenticatedSession(
        userId: 'user-123',
        status: 'ACTIVE',
        accessToken: 'new-access-token',
        refreshToken: 'new-refresh-token',
        tokenType: 'Bearer',
        accessTokenExpiresAt: DateTime.now().add(const Duration(minutes: 15)),
        user: const UserSummary(
          id: 'user-123',
          email: 'test@example.com',
          username: 'testuser',
          displayName: 'Test User',
        ),
      );

      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(builder: (c) {
              context = c;
              return const SizedBox();
            }),
          ),
        ),
      );

      expect(controller.status, AuthSessionStatus.unauthenticated);

      await coordinator.login(context, 'test@example.com', 'password');
      await tester.pump();

      expect(controller.status, AuthSessionStatus.authenticated);
      expect(holder.currentAccessToken, 'new-access-token');
      expect(store.values[SecureStorageService.accessTokenKey], 'new-access-token');
      expect(store.values[SecureStorageService.refreshTokenKey], 'new-refresh-token');
    });

    testWidgets('complete-profile login clears old session and marks controller unauthenticated', (tester) async {
      store.values[SecureStorageService.accessTokenKey] = 'old-access';
      store.values[SecureStorageService.refreshTokenKey] = 'old-refresh';
      holder.setAccessToken('old-access');
      controller.markAuthenticated();

      api.loginResult = const ProfileCompletionRequired(
        userId: 'user-456',
        status: 'PENDING_PROFILE',
        profileCompletionToken: 'profile-token-456',
      );

      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(builder: (c) {
              context = c;
              return const SizedBox();
            }),
          ),
          onGenerateRoute: (s) => MaterialPageRoute(builder: (_) => const SizedBox()),
        ),
      );

      await coordinator.login(context, 'new@example.com', 'password');
      await tester.pump();

      expect(controller.status, AuthSessionStatus.unauthenticated);
      expect(holder.currentAccessToken, isNull);
      expect(store.values, isEmpty);
      expect(coordinator.hasProfileCompletionToken, isTrue);
    });

    testWidgets('failed login preserves existing session status (does not force unauthenticated)', (tester) async {
      controller.markAuthenticated();
      holder.setAccessToken('existing-access');
      api.throwOnLogin = const ApiException(
        statusCode: 401,
        code: 'AUTH_INVALID_CREDENTIALS',
        message: 'Invalid credentials',
      );

      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(builder: (c) {
              context = c;
              return const SizedBox();
            }),
          ),
        ),
      );

      await coordinator.login(context, 'test@example.com', 'wrong-pass');
      await tester.pump();

      expect(controller.status, AuthSessionStatus.authenticated);
      expect(holder.currentAccessToken, 'existing-access');
    });

    testWidgets('complete-profile login clear failure marks controller unauthenticated and aborts onboarding', (tester) async {
      controller.markAuthenticated();
      holder.setAccessToken('existing-access');
      store.values[SecureStorageService.accessTokenKey] = 'existing-access';
      store.failOnDelete = true;

      api.loginResult = const ProfileCompletionRequired(
        userId: 'user-789',
        status: 'PENDING_PROFILE',
        profileCompletionToken: 'profile-token-789',
      );

      var navigated = false;
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(builder: (c) {
              context = c;
              return const SizedBox();
            }),
          ),
          onGenerateRoute: (s) {
            navigated = true;
            return MaterialPageRoute(builder: (_) => const SizedBox());
          },
        ),
      );

      await coordinator.login(context, 'test@example.com', 'password');
      await tester.pump();

      // In-memory bearer was destroyed by clearLocalSession failure recovery
      expect(controller.status, AuthSessionStatus.unauthenticated);
      expect(holder.currentAccessToken, isNull);
      // New onboarding flow was NOT established
      expect(coordinator.hasProfileCompletionToken, isFalse);
      expect(navigated, isFalse);
    });

    group('markUnauthenticatedIfRevision', () {
      test('matching revision updates status to unauthenticated and returns true', () {
        controller.markAuthenticated();
        holder.setAccessToken('token');
        final currentRev = holder.revision;

        final didUpdate = controller.markUnauthenticatedIfRevision(currentRev);

        expect(didUpdate, isTrue);
        expect(controller.status, AuthSessionStatus.unauthenticated);
      });

      test('mismatched revision preserves status and returns false', () {
        controller.markAuthenticated();
        holder.setAccessToken('token');
        final currentRev = holder.revision;

        final didUpdate = controller.markUnauthenticatedIfRevision(currentRev - 1);

        expect(didUpdate, isFalse);
        expect(controller.status, AuthSessionStatus.authenticated);
      });
    });
  });
}

class TestSecureStore implements SecureKeyValueStore {
  final Map<String, String> values = {};
  final List<String> deletedKeys = [];
  bool failOnRead = false;
  bool failOnDelete = false;

  @override
  Future<void> delete(String key) async {
    if (failOnDelete) throw StateError('simulated delete failure');
    deletedKeys.add(key);
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async {
    if (failOnRead) throw StateError('simulated read failure');
    return values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

class TestApi extends AuthApi {
  final List<String> networkCalls = [];
  int currentUserCalls = 0;
  int refreshCalls = 0;
  LoginResult? loginResult;
  ApiException? throwOnLogin;

  TestApi() : super(Dio(), refreshDio: Dio());

  @override
  Future<LoginResult> login({
    required String email,
    required String password,
    String? deviceName,
  }) async {
    networkCalls.add('login');
    if (throwOnLogin != null) throw throwOnLogin!;
    return loginResult ??
        AuthenticatedSession(
          userId: 'default-user',
          status: 'ACTIVE',
          accessToken: 'access',
          refreshToken: 'refresh',
          tokenType: 'Bearer',
          accessTokenExpiresAt: DateTime.now().add(const Duration(minutes: 15)),
          user: const UserSummary(
            id: 'default-user',
            email: 'default@example.com',
            username: 'default',
            displayName: 'Default',
          ),
        );
  }

  @override
  Future<CurrentUser> getCurrentUser() async {
    networkCalls.add('getCurrentUser');
    currentUserCalls++;
    return const CurrentUser(
      id: 'user-1',
      email: 'user@example.com',
      status: 'ACTIVE',
      emailVerified: true,
    );
  }
}
