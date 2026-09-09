import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/access_token_holder.dart';
import 'package:mobile/core/network/api_config.dart';
import 'package:mobile/core/network/dio_client.dart';
import 'package:mobile/core/storage/secure_key_value_store.dart';
import 'package:mobile/core/storage/secure_storage_service.dart';
import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_failure.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';
import 'package:mobile/features/auth/data/models/auth_models.dart';

void main() {
  group('Auth Session Integration & Security Proof (M2.14.7)', () {
    late AccessTokenHolder tokenHolder;
    late InMemorySecureStore store;
    late SecureStorageService storage;
    late TestHttpClientAdapter adapter;
    late DioClient dioClient;
    late AuthApi api;
    late AuthRepository repository;

    setUp(() {
      tokenHolder = AccessTokenHolder();
      store = InMemorySecureStore();
      storage = SecureStorageService(store: store);
      adapter = TestHttpClientAdapter();

      final dio = Dio()..httpClientAdapter = adapter;
      dioClient = DioClient(
        apiConfig: ApiConfig(baseUrl: 'https://api.wedo.test'),
        accessTokenHolder: tokenHolder,
        dio: dio,
      );

      api = AuthApi(dioClient.dio, refreshDio: Dio());
      repository = AuthRepository(
        api: api,
        storage: storage,
        accessTokenHolder: tokenHolder,
      );
    });

    group('TEST 1 — Full /me Authorization Chain', () {
      test(
        'attaches in-memory Bearer token to /me, maps all fields, and avoids retry/refresh/mutation',
        () async {
          tokenHolder.setAccessToken('token-A');
          await storage.writeSession(
            accessToken: 'token-A',
            refreshToken: 'refresh-A',
          );

          adapter.onPath(
            '/api/v1/me',
            const MockResponse(
              statusCode: 200,
              body: {
                'id': 'usr-001',
                'email': 'alice@example.com',
                'status': 'ACTIVE',
                'emailVerified': true,
                'username': 'alice',
                'phone': '+1234567890',
                'displayName': 'Alice Smith',
                'avatarStorageKey': 'avatars/alice.png',
                'bio': 'Collaborative builder',
              },
            ),
          );

          final user = await repository.getCurrentUser();

          // Transport assertions
          expect(adapter.requests, hasLength(1));
          final req = adapter.requests.single;
          expect(req.method, 'GET');
          expect(req.uri.path, '/api/v1/me');
          expect(req.headers['Authorization'], 'Bearer token-A');

          // Mapping assertions (all fields)
          expect(user.id, 'usr-001');
          expect(user.email, 'alice@example.com');
          expect(user.status, 'ACTIVE');
          expect(user.emailVerified, isTrue);
          expect(user.username, 'alice');
          expect(user.phone, '+1234567890');
          expect(user.displayName, 'Alice Smith');
          expect(user.avatarStorageKey, 'avatars/alice.png');
          expect(user.bio, 'Collaborative builder');

          // Boundaries: no /refresh called, no retry, session not mutated
          expect(
            adapter.requests.any((r) => r.uri.path.contains('refresh')),
            isFalse,
          );
          expect(tokenHolder.currentAccessToken, 'token-A');
          expect(await storage.readAccessToken(), 'token-A');
          expect(await storage.readRefreshToken(), 'refresh-A');
        },
      );

      test('handles nullable CurrentUser fields when backend returns nulls', () async {
        tokenHolder.setAccessToken('token-A');

        adapter.onPath(
          '/api/v1/me',
          const MockResponse(
            statusCode: 200,
            body: {
              'id': 'usr-002',
              'email': 'bob@example.com',
              'status': 'PENDING',
              'emailVerified': false,
              'username': null,
              'phone': null,
              'displayName': null,
              'avatarStorageKey': null,
              'bio': null,
            },
          ),
        );

        final user = await repository.getCurrentUser();

        expect(user.id, 'usr-002');
        expect(user.email, 'bob@example.com');
        expect(user.status, 'PENDING');
        expect(user.emailVerified, isFalse);
        expect(user.username, isNull);
        expect(user.phone, isNull);
        expect(user.displayName, isNull);
        expect(user.avatarStorageKey, isNull);
        expect(user.bio, isNull);
      });
    });

    group('TEST 2 — Logout Remote Success', () {
      test(
        'sends refresh token to backend logout, clears durable and in-memory tokens, and succeeds',
        () async {
          await storage.writeSession(
            accessToken: 'access-A',
            refreshToken: 'refresh-A',
          );
          tokenHolder.setAccessToken('access-A');

          adapter.onPath(
            '/api/v1/auth/logout',
            const MockResponse(statusCode: 204),
          );

          final result = await repository.logout();

          expect(result.remoteRevocationSucceeded, isTrue);

          // Remote call assertions
          expect(adapter.requests, hasLength(1));
          final req = adapter.requests.single;
          expect(req.method, 'POST');
          expect(req.uri.path, '/api/v1/auth/logout');
          expect(req.data, {'refreshToken': 'refresh-A'});
          expect(req.headers, isNot(contains('Authorization')));

          // Local clearing assertions
          expect(await storage.readAccessToken(), isNull);
          expect(await storage.readRefreshToken(), isNull);
          expect(store.isEmpty, isTrue);
          expect(tokenHolder.currentAccessToken, isNull);
        },
      );
    });

    group('TEST 3 — Logout Remote Failure', () {
      test(
        'still clears durable and in-memory tokens and reports remoteRevocationSucceeded = false',
        () async {
          await storage.writeSession(
            accessToken: 'access-A',
            refreshToken: 'refresh-A',
          );
          tokenHolder.setAccessToken('access-A');

          adapter.onPath(
            '/api/v1/auth/logout',
            const MockResponse(
              statusCode: 401,
              body: {'code': 'REFRESH_TOKEN_INVALID', 'message': 'Invalid token'},
            ),
          );

          final result = await repository.logout();

          expect(result.remoteRevocationSucceeded, isFalse);

          // Local state MUST still be cleared
          expect(await storage.readAccessToken(), isNull);
          expect(await storage.readRefreshToken(), isNull);
          expect(store.isEmpty, isTrue);
          expect(tokenHolder.currentAccessToken, isNull);
        },
      );

      test(
        'transport/network error on logout still clears local credentials safely',
        () async {
          await storage.writeSession(
            accessToken: 'access-A',
            refreshToken: 'refresh-A',
          );
          tokenHolder.setAccessToken('access-A');

          adapter.exceptionBuilder = (options) => DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              );

          final result = await repository.logout();

          expect(result.remoteRevocationSucceeded, isFalse);
          expect(await storage.readAccessToken(), isNull);
          expect(await storage.readRefreshToken(), isNull);
          expect(store.isEmpty, isTrue);
          expect(tokenHolder.currentAccessToken, isNull);
        },
      );
    });

    group('TEST 4 — Logout Without Refresh Token', () {
      test(
        'skips backend call, clears durable and in-memory state, and succeeds',
        () async {
          await store.write(
            key: SecureStorageService.accessTokenKey,
            value: 'access-A',
          );
          tokenHolder.setAccessToken('access-A');

          final result = await repository.logout();

          expect(result.remoteRevocationSucceeded, isTrue);
          expect(adapter.requests, isEmpty);
          expect(await storage.readAccessToken(), isNull);
          expect(await storage.readRefreshToken(), isNull);
          expect(store.isEmpty, isTrue);
          expect(tokenHolder.currentAccessToken, isNull);
        },
      );
    });

    group('TEST 5 — Public / Protected Interceptor Boundary', () {
      test(
        'attaches Bearer only to /me and excludes /auth/logout, /auth/login, and /health',
        () async {
          tokenHolder.setAccessToken('active-access-token');

          adapter.onPath(
            '/api/v1/me',
            const MockResponse(
              statusCode: 200,
              body: {
                'id': 'usr-1',
                'email': 'a@b.c',
                'status': 'ACTIVE',
                'emailVerified': true,
              },
            ),
          );
          adapter.onPath(
            '/api/v1/auth/logout',
            const MockResponse(statusCode: 204),
          );
          adapter.onPath(
            '/api/v1/auth/login',
            const MockResponse(
              statusCode: 200,
              body: {
                'userId': 'usr-1',
                'status': 'ACTIVE',
                'nextStep': 'COMPLETE_PROFILE',
                'profileCompletionToken': 'pct-123',
              },
            ),
          );
          adapter.onPath(
            '/api/v1/health',
            const MockResponse(statusCode: 200, body: {'status': 'UP'}),
          );

          // 1. Protected endpoint: /api/v1/me
          await api.getCurrentUser();
          expect(
            adapter.requests.last.headers['Authorization'],
            'Bearer active-access-token',
          );

          // 2. Public auth endpoint: /api/v1/auth/logout
          await api.logout('some-refresh-token');
          expect(
            adapter.requests.last.headers,
            isNot(contains('Authorization')),
          );

          // 3. Public auth endpoint: /api/v1/auth/login
          await api.login(email: 'a@b.c', password: 'raw-password');
          expect(
            adapter.requests.last.headers,
            isNot(contains('Authorization')),
          );

          // 4. Public health endpoint: /api/v1/health
          await dioClient.dio.get<void>('/api/v1/health');
          expect(
            adapter.requests.last.headers,
            isNot(contains('Authorization')),
          );
        },
      );
    });

    group('M2.15 Boundaries — Token Expiration & Non-Interference', () {
      test(
        'expired token on /me throws AuthException without retry, refresh, or session mutation',
        () async {
          tokenHolder.setAccessToken('expired-access-token');
          await storage.writeSession(
            accessToken: 'expired-access-token',
            refreshToken: 'valid-refresh-token',
          );

          adapter.onPath(
            '/api/v1/me',
            const MockResponse(
              statusCode: 401,
              body: {
                'code': 'AUTH_TOKEN_EXPIRED',
                'message': 'Access token has expired',
              },
            ),
          );

          await expectLater(
            repository.getCurrentUser(),
            throwsA(
              isA<AuthException>().having(
                (e) => e.failure.backendCode,
                'backendCode',
                'AUTH_TOKEN_EXPIRED',
              ),
            ),
          );

          // Exactly one request was made: NO retry, NO auto-refresh
          expect(adapter.requests, hasLength(1));
          expect(
            adapter.requests.any((r) => r.uri.path.contains('refresh')),
            isFalse,
          );

          // M2.15 boundary: session state is NOT cleared automatically here
          expect(tokenHolder.currentAccessToken, 'expired-access-token');
          expect(await storage.readAccessToken(), 'expired-access-token');
          expect(await storage.readRefreshToken(), 'valid-refresh-token');
        },
      );

      test('clearLocalSession clears stored and in-memory tokens with no remote calls', () async {
        await storage.writeSession(
          accessToken: 'token-to-clear',
          refreshToken: 'refresh-to-clear',
        );
        tokenHolder.setAccessToken('token-to-clear');

        await repository.clearLocalSession();

        expect(await storage.readAccessToken(), isNull);
        expect(await storage.readRefreshToken(), isNull);
        expect(store.isEmpty, isTrue);
        expect(tokenHolder.currentAccessToken, isNull);
        expect(adapter.requests, isEmpty);
      });
    });

    group('Security & Token Isolation Assertions', () {
      test('CurrentUser model contains only profile fields and ignores sensitive tokens', () {
        final user = CurrentUser.fromJson({
          'id': 'usr-123',
          'email': 'user@example.com',
          'status': 'ACTIVE',
          'emailVerified': true,
          'username': 'uname',
          'phone': null,
          'displayName': 'Display',
          'avatarStorageKey': null,
          'bio': null,
          'accessToken': 'malicious-injected-token',
          'refreshToken': 'malicious-injected-refresh',
        });

        // Verifying through instance fields
        expect(user.id, 'usr-123');
        expect(user.email, 'user@example.com');
        expect(user.status, 'ACTIVE');
        expect(user.emailVerified, isTrue);
        expect(user.username, 'uname');
        expect(user.displayName, 'Display');
        expect(user.phone, isNull);
        expect(user.avatarStorageKey, isNull);
        expect(user.bio, isNull);
      });
    });
  });
}

class InMemorySecureStore implements SecureKeyValueStore {
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

  bool get isEmpty => _data.isEmpty;
}

class MockResponse {
  final int statusCode;
  final dynamic body;
  final Map<String, List<String>>? headers;

  const MockResponse({
    this.statusCode = 200,
    this.body,
    this.headers,
  });
}

class TestHttpClientAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final Map<String, MockResponse> _pathResponses = {};
  DioException Function(RequestOptions)? exceptionBuilder;

  void onPath(String path, MockResponse response) {
    _pathResponses[path] = response;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    if (exceptionBuilder != null) {
      throw exceptionBuilder!(options);
    }

    final mock = _pathResponses[options.uri.path];
    if (mock == null) {
      return ResponseBody.fromString(
        '{"code":"NOT_FOUND"}',
        404,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    final bodyString = mock.body == null
        ? ''
        : mock.body is String
            ? mock.body as String
            : jsonEncode(mock.body);

    return ResponseBody.fromString(
      bodyString,
      mock.statusCode,
      headers: mock.headers ??
          {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
    );
  }

  @override
  void close({bool force = false}) {}
}
