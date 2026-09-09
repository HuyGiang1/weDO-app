import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/auth/session_invalidation_outcome.dart';
import 'package:mobile/core/network/access_token_holder.dart';
import 'package:mobile/core/storage/secure_key_value_store.dart';
import 'package:mobile/core/storage/secure_storage_service.dart';
import 'package:mobile/features/auth/application/auth_session_controller.dart';
import 'package:mobile/features/auth/application/auth_session_invalidator.dart';
import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_failure.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';

class FakeMemoryStore implements SecureKeyValueStore {
  final values = <String, String>{};
  bool failDeletes = false;

  @override
  Future<void> delete(String k) async {
    if (failDeletes) throw StateError('Delete failed');
    values.remove(k);
  }

  @override
  Future<String?> read(String k) async => values[k];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

class FakeAuthApi extends AuthApi {
  FakeAuthApi() : super(Dio(), refreshDio: Dio());
}

void main() {
  group('AuthSessionInvalidator - Classification allow-list', () {
    test('explicit allow-list classifies only definitive refresh failures as true', () {
      final definitiveTypes = {
        AuthFailureType.refreshTokenInvalid,
        AuthFailureType.noRefreshableSession,
        AuthFailureType.refreshSessionUnrecoverable,
        AuthFailureType.accountSuspended,
        AuthFailureType.accountDeactivated,
        AuthFailureType.emailNotVerified,
      };

      for (final type in AuthFailureType.values) {
        final failure = AuthFailure(type);
        final isDefinitive = AuthSessionInvalidator.isDefinitiveRefreshFailure(failure);
        if (definitiveTypes.contains(type)) {
          expect(isDefinitive, isTrue, reason: '$type should be definitive');
        } else {
          expect(isDefinitive, isFalse, reason: '$type should be non-destructive');
        }
      }
    });
  });

  group('AuthSessionInvalidator - Lifecycle & Concurrency', () {
    late FakeMemoryStore store;
    late SecureStorageService storage;
    late AccessTokenHolder holder;
    late AuthRepository repo;
    late AuthSessionController controller;
    late AuthSessionInvalidator invalidator;

    setUp(() {
      store = FakeMemoryStore();
      storage = SecureStorageService(store: store);
      holder = AccessTokenHolder();
      repo = AuthRepository(
        api: FakeAuthApi(),
        storage: storage,
        accessTokenHolder: holder,
      );
      controller = AuthSessionController(
        storage: storage,
        accessTokenHolder: holder,
        repository: repo,
        initialStatus: AuthSessionStatus.authenticated,
      );
      invalidator = AuthSessionInvalidator(
        repository: repo,
        sessionController: controller,
      );
    });

    // Requirement 20: Definitive refresh failure matrix
    for (final definitiveType in [
      AuthFailureType.refreshTokenInvalid,
      AuthFailureType.noRefreshableSession,
      AuthFailureType.refreshSessionUnrecoverable,
      AuthFailureType.accountSuspended,
      AuthFailureType.accountDeactivated,
      AuthFailureType.emailNotVerified,
    ]) {
      test('definitive failure $definitiveType invalidates matching session generation', () async {
        store.values[SecureStorageService.accessTokenKey] = 'access-10';
        store.values[SecureStorageService.refreshTokenKey] = 'refresh-10';
        for (var i = 0; i < 10; i++) {
          holder.setAccessToken('tok-$i');
        }
        expect(holder.revision, 10);
        expect(controller.isAuthenticated, isTrue);

        await invalidator.handleRefreshFailure(
          failure: AuthFailure(definitiveType),
          expectedRevision: 10,
        );

        expect(holder.currentAccessToken, isNull);
        expect(holder.revision, 11);
        expect(store.values, isEmpty);
        expect(controller.status, AuthSessionStatus.unauthenticated);
      });
    }

    // Requirement 21: Transient failure matrix
    for (final transientType in [
      AuthFailureType.network,
      AuthFailureType.timeout,
      AuthFailureType.unexpected,
    ]) {
      test('transient failure $transientType does NOT invalidate or log out', () async {
        store.values[SecureStorageService.accessTokenKey] = 'access-10';
        store.values[SecureStorageService.refreshTokenKey] = 'refresh-10';
        for (var i = 0; i < 10; i++) {
          holder.setAccessToken('tok-$i');
        }
        expect(holder.revision, 10);
        expect(controller.isAuthenticated, isTrue);

        await invalidator.handleRefreshFailure(
          failure: AuthFailure(transientType),
          expectedRevision: 10,
        );

        expect(holder.currentAccessToken, 'tok-9');
        expect(holder.revision, 10);
        expect(store.values[SecureStorageService.accessTokenKey], 'access-10');
        expect(controller.status, AuthSessionStatus.authenticated);
      });
    }

    // Requirement 22: Superseded refresh failure
    test('refreshSessionSuperseded failure does NOT invalidate or mutate controller', () async {
      store.values[SecureStorageService.accessTokenKey] = 'access-B';
      store.values[SecureStorageService.refreshTokenKey] = 'refresh-B';
      for (var i = 0; i < 11; i++) {
        holder.setAccessToken('tok-$i');
      }
      expect(holder.revision, 11);
      expect(controller.isAuthenticated, isTrue);

      await invalidator.handleRefreshFailure(
        failure: const AuthFailure(AuthFailureType.refreshSessionSuperseded),
        expectedRevision: 10,
      );

      expect(holder.currentAccessToken, 'tok-10');
      expect(holder.revision, 11);
      expect(store.values[SecureStorageService.accessTokenKey], 'access-B');
      expect(controller.status, AuthSessionStatus.authenticated);
    });

    // Requirement 23: Durable clear failure test
    test('durable clear failure clears RAM and marks controller unauthenticated without throwing', () async {
      store.values[SecureStorageService.accessTokenKey] = 'access-10';
      store.values[SecureStorageService.refreshTokenKey] = 'refresh-10';
      for (var i = 0; i < 10; i++) {
        holder.setAccessToken('tok-$i');
      }
      expect(holder.revision, 10);
      expect(controller.isAuthenticated, isTrue);

      store.failDeletes = true;

      await invalidator.handleRefreshFailure(
        failure: const AuthFailure(AuthFailureType.refreshTokenInvalid),
        expectedRevision: 10,
      );

      // RAM is cleared even when durable deletion fails
      expect(holder.currentAccessToken, isNull);
      expect(holder.revision, 11);
      // Controller still transitions to unauthenticated
      expect(controller.status, AuthSessionStatus.unauthenticated);
    });

    // Requirement 15 & 16: TOCTOU protection between invalidation and controller update
    test('controller TOCTOU guard: new login between invalidation and controller update preserves authenticated status', () async {
      for (var i = 0; i < 10; i++) {
        holder.setAccessToken('tok-$i');
      }
      expect(holder.revision, 10);
      controller.markAuthenticated();

      // Simulate invalidation applies 10 -> 11
      final outcome = await repo.invalidateLocalSession(expectedRevision: 10);
      expect(outcome, isA<SessionInvalidationApplied>());
      final applied = outcome as SessionInvalidationApplied;
      expect(applied.transition.toRevision, 11);

      // Before controller update runs, a new login (Account B) occurs: 11 -> 12
      holder.setAccessToken('account-B-token');
      expect(holder.revision, 12);
      controller.markAuthenticated();

      // Now stale invalidation continuation runs with toRevision 11
      final didUpdate = controller.markUnauthenticatedIfRevision(applied.transition.toRevision);
      expect(didUpdate, isFalse);
      expect(controller.status, AuthSessionStatus.authenticated);
    });

    // Requirement 18: Current AUTH_TOKEN_INVALID
    test('handleAccessTokenInvalid with matching revision clears session and updates controller', () async {
      store.values[SecureStorageService.accessTokenKey] = 'access-10';
      store.values[SecureStorageService.refreshTokenKey] = 'refresh-10';
      for (var i = 0; i < 10; i++) {
        holder.setAccessToken('tok-$i');
      }
      expect(holder.revision, 10);
      expect(controller.isAuthenticated, isTrue);

      await invalidator.handleAccessTokenInvalid(expectedRevision: 10);

      expect(holder.currentAccessToken, isNull);
      expect(holder.revision, 11);
      expect(store.values, isEmpty);
      expect(controller.status, AuthSessionStatus.unauthenticated);
    });

    // Requirement 19: Late AUTH_TOKEN_INVALID cross-account
    test('handleAccessTokenInvalid for older revision does not affect newer Account B session', () async {
      store.values[SecureStorageService.accessTokenKey] = 'access-B';
      store.values[SecureStorageService.refreshTokenKey] = 'refresh-B';
      for (var i = 0; i < 11; i++) {
        holder.setAccessToken('tok-B-$i');
      }
      expect(holder.revision, 11);
      expect(controller.isAuthenticated, isTrue);

      // Stale request from rev 10 receives 401 AUTH_TOKEN_INVALID
      await invalidator.handleAccessTokenInvalid(expectedRevision: 10);

      // Account B session is untouched
      expect(holder.currentAccessToken, 'tok-B-10');
      expect(holder.revision, 11);
      expect(store.values[SecureStorageService.accessTokenKey], 'access-B');
      expect(controller.status, AuthSessionStatus.authenticated);
    });
  });
}
