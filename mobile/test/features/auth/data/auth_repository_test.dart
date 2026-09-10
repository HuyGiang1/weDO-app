import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/auth/session_invalidation_outcome.dart';
import 'package:mobile/core/auth/session_revision.dart';
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

  test(
    'logout with remote success and storage clearing failure revokes remotely, clears memory bearer, advances revision, and leaves queue usable',
    () async {
      store.values[SecureStorageService.accessTokenKey] = 'access-1';
      store.values[SecureStorageService.refreshTokenKey] = 'refresh-1';
      holder.setAccessToken('access-1');
      final initialRevision = holder.revision;
      store.failDeletes = true;

      await expectLater(
        repo.logout(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.failure.type,
            'failure.type',
            AuthFailureType.unexpected,
          ),
        ),
      );

      // 1. Stored refresh token R existed and api.logout(R) was called exactly once
      expect(api.logoutToken, 'refresh-1');
      expect(api.logoutCalls, 1);

      // 2. AccessTokenHolder in-memory bearer is null and revision advanced by exactly 1
      expect(holder.currentAccessToken, isNull);
      expect(holder.revision, initialRevision + 1);

      // 3. Credential mutation queue remains usable afterward (not poisoned)
      store.failDeletes = false;
      await repo.clearLocalSession();
      expect(holder.currentAccessToken, isNull);
      expect(holder.revision, initialRevision + 2);
      expect(store.values, isEmpty);

      // 4. No duplicate remote logout occurred during subsequent local clear
      expect(api.logoutCalls, 1);
    },
  );

  group('AuthRepository.refreshSession', () {
    test('success path: reads old refresh token, calls API, atomically persists new pair, updates holder', () async {
      store.values[SecureStorageService.accessTokenKey] = 'access-old';
      store.values[SecureStorageService.refreshTokenKey] = 'refresh-old';
      holder.setAccessToken('access-old');
      final fromRev = holder.revision;

      final SessionRevisionTransition transition =
          await repo.refreshSession(expectedRevision: fromRev);

      expect(transition, isA<SessionRevisionTransition>());
      expect(transition.fromRevision, fromRev);
      expect(transition.toRevision, holder.revision);
      expect(transition.toRevision, greaterThan(fromRev));
      expect(api.refreshTokenArg, 'refresh-old');
      expect(store.values[SecureStorageService.accessTokenKey], 'new-access');
      expect(store.values[SecureStorageService.refreshTokenKey], 'new-refresh');
      expect(holder.currentAccessToken, 'new-access');
    });

    test('missing or blank refresh token throws noRefreshableSession with zero API calls', () async {
      // Null token
      await expectLater(
        repo.refreshSession(expectedRevision: holder.revision),
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
        repo.refreshSession(expectedRevision: holder.revision),
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

    test('storage write failure after rotation detects and throws refreshSessionUnrecoverable without ad-hoc clearing', () async {
      store.values[SecureStorageService.accessTokenKey] = 'access-old';
      store.values[SecureStorageService.refreshTokenKey] = 'refresh-old';
      holder.setAccessToken('access-old');
      store.fail = true;

      await expectLater(
        repo.refreshSession(expectedRevision: holder.revision),
        throwsA(
          isA<AuthException>().having(
            (e) => e.failure.type,
            'type',
            AuthFailureType.refreshSessionUnrecoverable,
          ),
        ),
      );

      // In M2.15.4, refreshSession does not perform ad-hoc clearing;
      // holder was not updated to new token and was not cleared by refreshSession.
      expect(holder.currentAccessToken, 'access-old');
      // Storage keys were cleared by SecureStorageService.writeSession to avoid partial session
      expect(store.values, isEmpty);
    });

    test('malformed success response detects and throws refreshSessionUnrecoverable without ad-hoc clearing', () async {
      store.values[SecureStorageService.accessTokenKey] = 'access-old';
      store.values[SecureStorageService.refreshTokenKey] = 'refresh-old';
      holder.setAccessToken('access-old');
      api.malformedRefresh = true;

      await expectLater(
        repo.refreshSession(expectedRevision: holder.revision),
        throwsA(
          isA<AuthException>().having(
            (e) => e.failure.type,
            'type',
            AuthFailureType.refreshSessionUnrecoverable,
          ),
        ),
      );

      // In M2.15.4, refreshSession does not perform ad-hoc clearing
      expect(holder.currentAccessToken, 'access-old');
      expect(store.values[SecureStorageService.accessTokenKey], 'access-old');
    });

    test('wrong JSON type or TypeError during refresh throws refreshSessionUnrecoverable without ad-hoc clearing', () async {
      store.values[SecureStorageService.accessTokenKey] = 'access-old';
      store.values[SecureStorageService.refreshTokenKey] = 'refresh-old';
      holder.setAccessToken('access-old');
      api.throwTypeErrorOnRefresh = true;

      await expectLater(
        repo.refreshSession(expectedRevision: holder.revision),
        throwsA(
          isA<AuthException>().having(
            (e) => e.failure.type,
            'type',
            AuthFailureType.refreshSessionUnrecoverable,
          ),
        ),
      );

      // In M2.15.4, refreshSession does not perform ad-hoc clearing
      expect(holder.currentAccessToken, 'access-old');
      expect(store.values[SecureStorageService.accessTokenKey], 'access-old');
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
        repo.refreshSession(expectedRevision: holder.revision),
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
        repo.refreshSession(expectedRevision: holder.revision),
        throwsA(
          isA<AuthException>().having(
            (e) => e.failure.type,
            'type',
            AuthFailureType.accountSuspended,
          ),
        ),
      );
    });

    // Requirement 24: Consistent Refresh Snapshot
    test('consistent refresh snapshot: superseded before API call if session revision changed', () async {
      for (var i = 0; i < 10; i++) {
        holder.setAccessToken('tok-$i');
      }
      expect(holder.revision, 10);
      store.values[SecureStorageService.refreshTokenKey] = 'refresh-A';

      // Account B login occurs, mutating holder to rev 11 and store with B's refresh token
      store.values[SecureStorageService.refreshTokenKey] = 'refresh-B';
      holder.setAccessToken('access-B');
      expect(holder.revision, 11);

      // Call refreshSession with expectedRevision: 10
      await expectLater(
        repo.refreshSession(expectedRevision: 10),
        throwsA(
          isA<AuthException>().having(
            (e) => e.failure.type,
            'type',
            AuthFailureType.refreshSessionSuperseded,
          ),
        ),
      );

      // B refresh token is NEVER sent to /auth/refresh
      expect(api.refreshTokenArg, isNull);
      // B holder and storage remain untouched
      expect(holder.currentAccessToken, 'access-B');
      expect(holder.revision, 11);
      expect(store.values[SecureStorageService.refreshTokenKey], 'refresh-B');
    });

    // Requirement 29: Refresh vs Logout
    test('refresh vs logout: rotated response is discarded and no resurrection if logout occurs during network call', () async {
      for (var i = 0; i < 10; i++) {
        holder.setAccessToken('tok-$i');
      }
      expect(holder.revision, 10);
      store.values[SecureStorageService.refreshTokenKey] = 'refresh-A';

      final networkCompleter = Completer<RefreshTokenResponse>();
      api.refreshCompleter = networkCompleter;

      final refreshFuture = repo.refreshSession(expectedRevision: 10);
      await pumpEventQueue();
      expect(api.refreshTokenArg, 'refresh-A');

      // Logout occurs while network call is in flight
      await repo.clearLocalSession();
      expect(store.values, isEmpty);
      expect(holder.currentAccessToken, isNull);
      final logoutRev = holder.revision;

      // Refresh completes after logout
      networkCompleter.complete(
        RefreshTokenResponse(
          accessToken: 'resurrect-access',
          refreshToken: 'resurrect-refresh',
          tokenType: 'Bearer',
          accessTokenExpiresAt: DateTime(2026),
          refreshTokenExpiresAt: DateTime(2026),
        ),
      );

      await expectLater(
        refreshFuture,
        throwsA(
          isA<AuthException>().having(
            (e) => e.failure.type,
            'type',
            AuthFailureType.refreshSessionSuperseded,
          ),
        ),
      );

      // Storage and holder remain empty; no resurrection
      expect(store.values, isEmpty);
      expect(holder.currentAccessToken, isNull);
      expect(holder.revision, logoutRev);
    });

    // Requirement 30: Refresh vs Login
    test('refresh vs login: old Account A refresh response discarded and Account B untouched', () async {
      for (var i = 0; i < 10; i++) {
        holder.setAccessToken('tok-$i');
      }
      expect(holder.revision, 10);
      store.values[SecureStorageService.refreshTokenKey] = 'refresh-A';

      final networkCompleter = Completer<RefreshTokenResponse>();
      api.refreshCompleter = networkCompleter;

      final refreshFuture = repo.refreshSession(expectedRevision: 10);
      await pumpEventQueue();
      expect(api.refreshTokenArg, 'refresh-A');

      // Account B logs in while network is pending
      await repo.login(email: 'user-b@example.com', password: 'password-b');
      expect(holder.currentAccessToken, 'access');
      expect(store.values[SecureStorageService.accessTokenKey], 'access');
      expect(store.values[SecureStorageService.refreshTokenKey], 'refresh');
      final revB = holder.revision;

      // Refresh A completes
      networkCompleter.complete(
        RefreshTokenResponse(
          accessToken: 'new-access-A',
          refreshToken: 'new-refresh-A',
          tokenType: 'Bearer',
          accessTokenExpiresAt: DateTime(2026),
          refreshTokenExpiresAt: DateTime(2026),
        ),
      );

      await expectLater(
        refreshFuture,
        throwsA(
          isA<AuthException>().having(
            (e) => e.failure.type,
            'type',
            AuthFailureType.refreshSessionSuperseded,
          ),
        ),
      );

      // Account B storage and holder remain untouched
      expect(holder.currentAccessToken, 'access');
      expect(holder.revision, revB);
      expect(store.values[SecureStorageService.refreshTokenKey], 'refresh');
    });

    // Requirement 30 (continued): Malformed HTTP-200 old-session response
    test('refresh vs login: malformed HTTP-200 old-session response must NOT clear Account B', () async {
      for (var i = 0; i < 10; i++) {
        holder.setAccessToken('tok-$i');
      }
      expect(holder.revision, 10);
      store.values[SecureStorageService.refreshTokenKey] = 'refresh-A';

      final networkCompleter = Completer<RefreshTokenResponse>();
      api.refreshCompleter = networkCompleter;

      final refreshFuture = repo.refreshSession(expectedRevision: 10);
      await pumpEventQueue();
      expect(api.refreshTokenArg, 'refresh-A');

      // Account B logs in while network is pending
      await repo.login(email: 'user-b@example.com', password: 'password-b');
      expect(holder.currentAccessToken, 'access');
      final revB = holder.revision;

      // Refresh A returns malformed HTTP-200 (FormatException / parsing error)
      networkCompleter.completeError(const FormatException('malformed json'));

      await expectLater(
        refreshFuture,
        throwsA(
          isA<AuthException>().having(
            (e) => e.failure.type,
            'type',
            AuthFailureType.refreshSessionSuperseded,
          ),
        ),
      );

      // Account B must NOT be cleared!
      expect(holder.currentAccessToken, 'access');
      expect(holder.revision, revB);
      expect(store.values[SecureStorageService.refreshTokenKey], 'refresh');
    });

    // Requirement 31: Mutation serialization
    test('credential mutation FIFO: local credential mutations cannot interleave', () async {
      final writeCompleter = Completer<void>();
      store.writePause = writeCompleter;

      // 1. Dispatch a login mutation that pauses during store.write
      final loginFuture = repo.login(email: 'a@b.com', password: 'pwd');
      await pumpEventQueue();

      // 2. Dispatch clearLocalSession while login is paused inside mutation queue
      var clearFinished = false;
      final clearFuture = repo.clearLocalSession().then((_) => clearFinished = true);
      await pumpEventQueue();

      // Clear has NOT finished because queue is held by login
      expect(clearFinished, isFalse);

      // 3. Unpause write
      writeCompleter.complete();
      await loginFuture;

      // Now clear finishes sequentially
      await clearFuture;
      expect(clearFinished, isTrue);
      expect(store.values, isEmpty);
      expect(holder.currentAccessToken, isNull);
    });

    // Requirement 32: Logout reentrancy
    test('logout reentrancy: completes normally without nested queue deadlock', () async {
      store.values[SecureStorageService.refreshTokenKey] = 'refresh-token';
      holder.setAccessToken('access-token');

      final result = await repo.logout();
      expect(result.remoteRevocationSucceeded, isTrue);
      expect(store.values, isEmpty);
      expect(holder.currentAccessToken, isNull);
    });

    test('mutation queue recovery: queue is not permanently poisoned by a failed mutation', () async {
      // Mutation A: login where storage write throws
      store.fail = true;
      await expectLater(
        repo.login(email: 'fail@example.com', password: 'password'),
        throwsA(isA<AuthException>()),
      );

      // Assert queue released and subsequent mutations execute normally
      store.fail = false;

      // Mutation B: clearLocalSession enters queue and completes normally
      holder.setAccessToken('valid-token');
      await repo.clearLocalSession();

      expect(holder.currentAccessToken, isNull);
      expect(store.values, isEmpty);

      // Mutation C: successful login enters queue and completes normally
      final result = await repo.login(email: 'success@example.com', password: 'password');
      expect(result, isA<AuthenticatedSession>());
      expect(holder.currentAccessToken, 'access');
      expect(store.values[SecureStorageService.accessTokenKey], 'access');
    });

    group('invalidateLocalSession', () {
      test('applied on matching revision: clears RAM, captures transition, clears durable storage', () async {
        store.values[SecureStorageService.accessTokenKey] = 'access-10';
        store.values[SecureStorageService.refreshTokenKey] = 'refresh-10';
        for (var i = 0; i < 10; i++) {
          holder.setAccessToken('tok-$i');
        }
        expect(holder.revision, 10);

        final outcome = await repo.invalidateLocalSession(expectedRevision: 10);

        expect(outcome, isA<SessionInvalidationApplied>());
        final applied = outcome as SessionInvalidationApplied;
        expect(applied.transition.fromRevision, 10);
        expect(applied.transition.toRevision, 11);
        expect(applied.durableCredentialsCleared, isTrue);

        expect(holder.currentAccessToken, isNull);
        expect(holder.revision, 11);
        expect(store.values, isEmpty);
      });

      test('superseded on revision mismatch: returns SessionInvalidationSuperseded, touches nothing', () async {
        store.values[SecureStorageService.accessTokenKey] = 'access-B';
        store.values[SecureStorageService.refreshTokenKey] = 'refresh-B';
        for (var i = 0; i < 11; i++) {
          holder.setAccessToken('tok-B-$i');
        }
        expect(holder.revision, 11);

        final outcome = await repo.invalidateLocalSession(expectedRevision: 10);

        expect(outcome, isA<SessionInvalidationSuperseded>());
        // Memory and durable storage completely untouched
        expect(holder.currentAccessToken, 'tok-B-10');
        expect(holder.revision, 11);
        expect(store.values[SecureStorageService.accessTokenKey], 'access-B');
        expect(store.values[SecureStorageService.refreshTokenKey], 'refresh-B');
      });

      test('durable-clear failure: clears RAM, captures transition, reports durableCredentialsCleared: false, queue remains usable', () async {
        store.values[SecureStorageService.accessTokenKey] = 'access-10';
        store.values[SecureStorageService.refreshTokenKey] = 'refresh-10';
        for (var i = 0; i < 10; i++) {
          holder.setAccessToken('tok-$i');
        }
        expect(holder.revision, 10);

        // Make delete throw
        store.failDeletes = true;

        final outcome = await repo.invalidateLocalSession(expectedRevision: 10);

        expect(outcome, isA<SessionInvalidationApplied>());
        final applied = outcome as SessionInvalidationApplied;
        expect(applied.transition.fromRevision, 10);
        expect(applied.transition.toRevision, 11);
        expect(applied.durableCredentialsCleared, isFalse);

        // RAM MUST be cleared even when durable deletion throws
        expect(holder.currentAccessToken, isNull);
        expect(holder.revision, 11);

        // Mutation queue must NOT be poisoned: subsequent login succeeds
        store.failDeletes = false;
        final loginResult = await repo.login(email: 'new@example.com', password: 'pwd');
        expect(loginResult, isA<AuthenticatedSession>());
        expect(holder.currentAccessToken, 'access');
        expect(holder.revision, 12);
        expect(store.values[SecureStorageService.accessTokenKey], 'access');
      });

      test('invalidation vs logout: logout changes revision, old invalidation is superseded', () async {
        store.values[SecureStorageService.accessTokenKey] = 'access-10';
        store.values[SecureStorageService.refreshTokenKey] = 'refresh-10';
        for (var i = 0; i < 10; i++) {
          holder.setAccessToken('tok-$i');
        }
        expect(holder.revision, 10);

        // User logs out first (10 -> 11)
        await repo.clearLocalSession();
        expect(holder.revision, 11);
        expect(holder.currentAccessToken, isNull);

        // Stale invalidation targeting rev 10
        final outcome = await repo.invalidateLocalSession(expectedRevision: 10);
        expect(outcome, isA<SessionInvalidationSuperseded>());
        expect(holder.revision, 11);
      });

      test('invalidation vs new login: Account B login completes first, stale invalidation for Account A is superseded', () async {
        store.values[SecureStorageService.accessTokenKey] = 'access-A';
        store.values[SecureStorageService.refreshTokenKey] = 'refresh-A';
        for (var i = 0; i < 10; i++) {
          holder.setAccessToken('tok-$i');
        }
        expect(holder.revision, 10);

        // Account B logs in (10 -> 11)
        await repo.login(email: 'user-b@example.com', password: 'pwd');
        expect(holder.revision, 11);
        expect(holder.currentAccessToken, 'access');
        expect(store.values[SecureStorageService.accessTokenKey], 'access');

        // Stale invalidation for Account A (target 10)
        final outcome = await repo.invalidateLocalSession(expectedRevision: 10);
        expect(outcome, isA<SessionInvalidationSuperseded>());

        // Account B session remains intact
        expect(holder.revision, 11);
        expect(holder.currentAccessToken, 'access');
        expect(store.values[SecureStorageService.accessTokenKey], 'access');
        expect(store.values[SecureStorageService.refreshTokenKey], 'refresh');
      });
    });
  });
}

class FakeApi extends AuthApi {
  FakeApi() : super(Dio(), refreshDio: Dio());
  String? email, password, code, username, profileToken, logoutToken, refreshTokenArg;
  int logoutCalls = 0;
  bool incomplete = false, failLogout = false, malformedRefresh = false, throwTypeErrorOnRefresh = false;
  ApiException? failRefreshWith;
  Completer<RefreshTokenResponse>? refreshCompleter;

  @override
  Future<RefreshTokenResponse> refreshToken(String refreshToken) async {
    refreshTokenArg = refreshToken;
    if (refreshCompleter != null) {
      return await refreshCompleter!.future;
    }
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
    logoutCalls++;
    logoutToken = token;
    if (failLogout) throw StateError('x');
  }
}

class MemoryStore implements SecureKeyValueStore {
  final values = <String, String>{};
  bool fail = false, failDeletes = false;
  Completer<void>? writePause;

  @override
  Future<void> delete(String k) async {
    if (failDeletes) throw StateError('x');
    values.remove(k);
  }

  @override
  Future<String?> read(String k) async => values[k];

  @override
  Future<void> write({required String key, required String value}) async {
    if (writePause != null) {
      await writePause!.future;
    }
    if (fail) throw StateError('x');
    values[key] = value;
  }
}
