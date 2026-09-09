import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/auth/session_revision.dart';
import 'package:mobile/core/network/access_token_holder.dart';
import 'package:mobile/core/network/auth_interceptor.dart';
import 'package:mobile/features/auth/data/auth_failure.dart';

void main() {
  group('AuthInterceptor', () {
    late AccessTokenHolder holder;
    late MockHttpClientAdapter adapter;
    late Dio dio;
    late int refreshCallCount;
    late List<int> expectedRevisionsCalled;
    Completer<SessionRevisionTransition>? refreshCompleter;

    setUp(() {
      holder = AccessTokenHolder();
      adapter = MockHttpClientAdapter();
      dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = adapter;
      refreshCallCount = 0;
      expectedRevisionsCalled = [];
      refreshCompleter = null;

      final interceptor = AuthInterceptor(
        accessTokenHolder: holder,
        refreshSession: ({required int expectedRevision}) async {
          refreshCallCount++;
          expectedRevisionsCalled.add(expectedRevision);
          if (refreshCompleter != null) {
            return await refreshCompleter!.future;
          }
          final toRev = expectedRevision + 1;
          holder.setAccessToken('token-rev$toRev');
          return SessionRevisionTransition(
            fromRevision: expectedRevision,
            toRevision: toRev,
          );
        },
        dio: dio,
      );

      dio.interceptors.add(interceptor);
    });

    // Requirement 25: Active Single-Flight
    test('active single-flight: 3 concurrent expired requests trigger exactly 1 refresh and all retry targeting new rev', () async {
      final cleanHolder = AccessTokenHolder();
      for (var i = 1; i <= 10; i++) {
        cleanHolder.setAccessToken('token-rev$i');
      }
      expect(cleanHolder.revision, 10);

      final cleanDio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      final cleanAdapter = MockHttpClientAdapter();
      cleanDio.httpClientAdapter = cleanAdapter;
      var cleanRefreshCalls = 0;
      final cleanCompleter = Completer<SessionRevisionTransition>();

      final cleanInterceptor = AuthInterceptor(
        accessTokenHolder: cleanHolder,
        refreshSession: ({required int expectedRevision}) async {
          cleanRefreshCalls++;
          return await cleanCompleter.future;
        },
        dio: cleanDio,
      );
      cleanDio.interceptors.add(cleanInterceptor);

      cleanAdapter.handler = (options) async {
        if (options.headers['Authorization'] == 'Bearer token-rev10') {
          return MockHttpClientAdapter.json(
            {'code': 'AUTH_TOKEN_EXPIRED', 'message': 'Token expired'},
            401,
          );
        }
        if (options.headers['Authorization'] == 'Bearer token-rev11') {
          return MockHttpClientAdapter.json(
            {'data': 'success-${options.path}'},
            200,
          );
        }
        return MockHttpClientAdapter.json({}, 400);
      };

      // Dispatch 3 protected requests at rev 10
      final f1 = cleanDio.get<Map<String, dynamic>>('/api/v1/res1');
      final f2 = cleanDio.get<Map<String, dynamic>>('/api/v1/res2');
      final f3 = cleanDio.get<Map<String, dynamic>>('/api/v1/res3');

      // Wait for all 3 to receive 401 and reach the refresh coordination boundary
      await pumpEventQueue();
      expect(cleanRefreshCalls, 1);

      // Mutate holder and complete refresh 10 -> 11
      cleanHolder.setAccessToken('token-rev11');
      expect(cleanHolder.revision, 11);
      cleanCompleter.complete(
        const SessionRevisionTransition(fromRevision: 10, toRevision: 11),
      );

      final r1 = await f1;
      final r2 = await f2;
      final r3 = await f3;

      expect(cleanRefreshCalls, 1);
      expect(r1.data?['data'], 'success-/api/v1/res1');
      expect(r2.data?['data'], 'success-/api/v1/res2');
      expect(r3.data?['data'], 'success-/api/v1/res3');

      // Assert: exactly 3 original requests (with token-rev10) and 3 retried requests (with token-rev11)
      final originalRequests = cleanAdapter.requests
          .where((r) => r.headers['Authorization'] == 'Bearer token-rev10')
          .toList();
      expect(originalRequests, hasLength(3));

      final retriedRequests = cleanAdapter.requests
          .where((r) => r.headers['Authorization'] == 'Bearer token-rev11')
          .toList();
      expect(retriedRequests, hasLength(3));
    });

    // Requirement 26: Late Stale-401
    test('late stale-401: late expired request retries without second refresh via proven transition', () async {
      holder.setAccessToken('token-rev1'); // rev 1
      final completerA = Completer<ResponseBody>();
      final completerB = Completer<ResponseBody>();

      adapter.handler = (options) async {
        if (options.path == '/api/v1/reqA') {
          if (options.headers['Authorization'] == 'Bearer token-rev1') {
            return completerA.future;
          }
          return MockHttpClientAdapter.json({'res': 'successA'}, 200);
        }
        if (options.path == '/api/v1/reqB') {
          if (options.headers['Authorization'] == 'Bearer token-rev1') {
            return completerB.future;
          }
          return MockHttpClientAdapter.json({'res': 'successB'}, 200);
        }
        return MockHttpClientAdapter.json({}, 400);
      };

      // Dispatch A and B under rev 1
      final fA = dio.get<Map<String, dynamic>>('/api/v1/reqA');
      final fB = dio.get<Map<String, dynamic>>('/api/v1/reqB');
      await pumpEventQueue();

      // A fails with 401 first
      completerA.complete(
        MockHttpClientAdapter.json({'code': 'AUTH_TOKEN_EXPIRED'}, 401),
      );

      // Wait for A to refresh (1 -> 2) and succeed on retry
      final rA = await fA;
      expect(rA.data?['res'], 'successA');
      expect(refreshCallCount, 1);
      expect(holder.revision, 2);

      // ONLY AFTERWARD, B receives 401 for its original rev 1 request
      completerB.complete(
        MockHttpClientAdapter.json({'code': 'AUTH_TOKEN_EXPIRED'}, 401),
      );

      final rB = await fB;
      expect(rB.data?['res'], 'successB');

      // Assert:
      // - NO second refresh
      expect(refreshCallCount, 1);
      // - B retried targeting rev 2 using token-rev2
      final bRequests = adapter.requests.where((r) => r.path == '/api/v1/reqB').toList();
      expect(bRequests, hasLength(2));
      expect(bRequests.first.headers['Authorization'], 'Bearer token-rev1');
      expect(bRequests.last.headers['Authorization'], 'Bearer token-rev2');
    });

    // Requirement 27: Post-Refresh Login Race
    test('post-refresh login race: interceptor never records 10->12 and does NOT retry under Account B', () async {
      holder.setAccessToken('token-rev10'); // rev 1

      adapter.handler = (options) async {
        if (options.headers['Authorization'] == 'Bearer token-rev10') {
          return MockHttpClientAdapter.json({'code': 'AUTH_TOKEN_EXPIRED'}, 401);
        }
        if (options.headers['Authorization'] == 'Bearer token-account-B') {
          return MockHttpClientAdapter.json({'secret': 'account-b-data'}, 200);
        }
        return MockHttpClientAdapter.json({}, 400);
      };

      final raceDio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      raceDio.httpClientAdapter = adapter;
      final raceInterceptor = AuthInterceptor(
        accessTokenHolder: holder,
        refreshSession: ({required int expectedRevision}) async {
          // Repository refresh succeeds 1 -> 2
          holder.setAccessToken('token-rev2'); // rev 2
          // But Account B immediately logs in before interceptor continuation finishes!
          holder.setAccessToken('token-account-B'); // rev 3
          return SessionRevisionTransition(
            fromRevision: expectedRevision,
            toRevision: 2, // returns exact 1 -> 2 transition
          );
        },
        dio: raceDio,
      );
      raceDio.interceptors.add(raceInterceptor);

      // Protected request with rev 1
      await expectLater(
        raceDio.get<Map<String, dynamic>>('/api/v1/account-a-action'),
        throwsA(isA<DioException>()),
      );

      // Assert:
      // - old rev 1 request was NOT retried under rev 3 (Account B)
      final accountBRequests = adapter.requests
          .where((r) => r.headers['Authorization'] == 'Bearer token-account-B')
          .toList();
      expect(accountBRequests, isEmpty);
      // - Account B token remains intact
      expect(holder.currentAccessToken, 'token-account-B');
      expect(holder.revision, 3);
    });

    // Requirement 28: Retry Dispatch Race / TOCTOU Guard
    test('retry dispatch race: retry aborted if session changes before network dispatch, zero cross-account replay', () async {
      holder.setAccessToken('token-rev1'); // rev 1

      adapter.handler = (options) async {
        if (options.headers['Authorization'] == 'Bearer token-rev1') {
          return MockHttpClientAdapter.json({'code': 'AUTH_TOKEN_EXPIRED'}, 401);
        }
        return MockHttpClientAdapter.json({}, 200);
      };

      final toctouDio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      toctouDio.httpClientAdapter = adapter;

      // An interceptor that runs right before retry dispatch and simulates Account B login
      toctouDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.extra['@wedo/auth_retry_target_revision'] != null) {
              // Session changes to Account B rev 3 right before retry dispatch
              holder.setAccessToken('token-account-B'); // rev becomes 3
            }
            handler.next(options);
          },
        ),
      );

      final toctouInterceptor = AuthInterceptor(
        accessTokenHolder: holder,
        refreshSession: ({required int expectedRevision}) async {
          holder.setAccessToken('token-rev2'); // rev 2
          return SessionRevisionTransition(
            fromRevision: expectedRevision,
            toRevision: 2,
          );
        },
        dio: toctouDio,
      );
      toctouDio.interceptors.add(toctouInterceptor);

      // Dispatched under rev 1
      await expectLater(
        toctouDio.get<Map<String, dynamic>>('/api/v1/sensitive-data'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            401,
          ),
        ),
      );

      // Assert:
      // - retry was aborted
      // - request was NOT sent with token-account-B
      final sentWithB = adapter.requests
          .where((r) => r.headers['Authorization'] == 'Bearer token-account-B')
          .toList();
      expect(sentWithB, isEmpty);
      expect(holder.currentAccessToken, 'token-account-B');
    });

    // Requirement 33: Other 401s
    test('other 401: AUTH_TOKEN_INVALID, UNAUTHORIZED, and AUTH_INVALID_CREDENTIALS do not refresh or retry', () async {
      holder.setAccessToken('token-1');

      for (final code in ['AUTH_TOKEN_INVALID', 'UNAUTHORIZED', 'AUTH_INVALID_CREDENTIALS', 'REFRESH_TOKEN_INVALID']) {
        adapter.handler = (options) async => MockHttpClientAdapter.json(
          {'code': code, 'message': 'Invalid'},
          401,
        );

        await expectLater(
          dio.get<void>('/api/v1/protected'),
          throwsA(
            isA<DioException>().having(
              (e) => (e.response?.data as Map)['code'],
              'error code',
              code,
            ),
          ),
        );
      }

      expect(refreshCallCount, 0);
      expect(adapter.requests, hasLength(4));
    });

    // Requirement 34: Retry Loop
    test('retry loop: retried request receiving AUTH_TOKEN_EXPIRED again does not refresh or retry a second time', () async {
      holder.setAccessToken('token-rev1');

      // Both initial and retried request receive 401 AUTH_TOKEN_EXPIRED
      adapter.handler = (options) async => MockHttpClientAdapter.json(
        {'code': 'AUTH_TOKEN_EXPIRED', 'message': 'Still expired'},
        401,
      );

      await expectLater(
        dio.get<void>('/api/v1/protected'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            401,
          ),
        ),
      );

      // Exactly 1 refresh and 1 retry
      expect(refreshCallCount, 1);
      expect(adapter.requests, hasLength(2));
      expect(adapter.requests.first.headers['Authorization'], 'Bearer token-rev1');
      expect(adapter.requests.last.headers['Authorization'], 'Bearer token-rev2');
    });

    // Requirement 35: Request Fidelity
    test('request fidelity: preserves method, path, query, JSON body, and custom headers upon retry', () async {
      holder.setAccessToken('token-rev1');

      adapter.handler = (options) async {
        if (options.headers['Authorization'] == 'Bearer token-rev1') {
          return MockHttpClientAdapter.json({'code': 'AUTH_TOKEN_EXPIRED'}, 401);
        }
        return MockHttpClientAdapter.json({'status': 'created'}, 201);
      };

      final response = await dio.post<Map<String, dynamic>>(
        '/api/v1/items',
        queryParameters: {'filter': 'active', 'limit': 10},
        data: {'name': 'Widget', 'quantity': 5},
        options: Options(
          headers: {'X-Custom-Safe-Header': 'safe-value-123'},
        ),
      );

      expect(response.statusCode, 201);
      expect(refreshCallCount, 1);
      expect(adapter.requests, hasLength(2));

      final retried = adapter.requests.last;
      expect(retried.method, 'POST');
      expect(retried.path, '/api/v1/items');
      expect(retried.queryParameters, {'filter': 'active', 'limit': 10});
      expect(retried.data, {'name': 'Widget', 'quantity': 5});
      expect(retried.headers['X-Custom-Safe-Header'], 'safe-value-123');
      expect(retried.headers['Authorization'], 'Bearer token-rev2');
      expect(retried.headers.containsKey('authorization'), isFalse);
    });

    // Refresh failure forwarding (Requirement 21)
    test('refresh failure forwarding: wraps refresh error in original DioException without calling session controller', () async {
      holder.setAccessToken('token-rev1');

      adapter.handler = (options) async => MockHttpClientAdapter.json(
        {'code': 'AUTH_TOKEN_EXPIRED'},
        401,
      );

      final failingDio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      failingDio.httpClientAdapter = adapter;
      final failingInterceptor = AuthInterceptor(
        accessTokenHolder: holder,
        refreshSession: ({required int expectedRevision}) async {
          throw const FormatException('Simulated unrecoverable refresh failure');
        },
        dio: failingDio,
      );
      failingDio.interceptors.add(failingInterceptor);

      await expectLater(
        failingDio.get<void>('/api/v1/protected'),
        throwsA(
          isA<DioException>().having(
            (e) => e.error,
            'error',
            isA<FormatException>(),
          ),
        ),
      );
    });

    // Requirement: Different-Generation Active Refresh Isolation
    test('different-generation active refresh: request from new generation does not join or overwrite active refresh', () async {
      final revHolder = AccessTokenHolder();
      for (var i = 1; i <= 10; i++) {
        revHolder.setAccessToken('token-rev$i');
      }
      expect(revHolder.revision, 10);

      final testDio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      final testAdapter = MockHttpClientAdapter();
      testDio.httpClientAdapter = testAdapter;

      var refreshCalls = 0;
      final rev10Completer = Completer<SessionRevisionTransition>();
      final rev11Completer = Completer<SessionRevisionTransition>();

      final testInterceptor = AuthInterceptor(
        accessTokenHolder: revHolder,
        refreshSession: ({required int expectedRevision}) async {
          refreshCalls++;
          if (expectedRevision == 10) {
            return await rev10Completer.future;
          } else if (expectedRevision == 11) {
            return await rev11Completer.future;
          }
          throw StateError('Unexpected expectedRevision $expectedRevision');
        },
        dio: testDio,
      );
      testDio.interceptors.add(testInterceptor);

      testAdapter.handler = (options) async {
        if (options.headers['Authorization'] == 'Bearer token-rev10') {
          return MockHttpClientAdapter.json(
            {'code': 'AUTH_TOKEN_EXPIRED', 'message': 'Token expired'},
            401,
          );
        }
        if (options.headers['Authorization'] == 'Bearer token-rev11') {
          if (options.path == '/api/v1/reqB') {
            return MockHttpClientAdapter.json(
              {'code': 'AUTH_TOKEN_EXPIRED', 'message': 'Token expired'},
              401,
            );
          }
          return MockHttpClientAdapter.json({'data': 'success-rev11'}, 200);
        }
        if (options.headers['Authorization'] == 'Bearer token-rev12') {
          return MockHttpClientAdapter.json({'data': 'success-rev12'}, 200);
        }
        return MockHttpClientAdapter.json({}, 400);
      };

      // 1. Request A rev10 receives AUTH_TOKEN_EXPIRED and starts refresh
      final fA = testDio.get<Map<String, dynamic>>('/api/v1/reqA');
      await pumpEventQueue();
      expect(refreshCalls, 1);

      // 2. While rev10 refresh is still active, session changes to rev11 (e.g. Account B logged in)
      revHolder.setAccessToken('token-rev11');
      expect(revHolder.revision, 11);

      // 3. Protected Request B belonging to rev11 receives 401 AUTH_TOKEN_EXPIRED
      await expectLater(
        testDio.get<Map<String, dynamic>>('/api/v1/reqB'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            401,
          ),
        ),
      );

      // Assert:
      // - Request B MUST NOT join rev10 refresh
      // - refreshCalls remains 1 (did not start concurrent refresh or overwrite metadata)
      expect(refreshCalls, 1);

      // 4. Complete old rev10 refresh with supersession (since session changed to rev 11)
      rev10Completer.completeError(
        const AuthException(
          AuthFailure(AuthFailureType.refreshSessionSuperseded),
        ),
      );

      // Request A fails because rev 10 refresh was superseded
      await expectLater(
        fA,
        throwsA(
          isA<DioException>().having(
            (e) => e.error,
            'error',
            isA<AuthException>().having(
              (ae) => ae.failure.type,
              'type',
              AuthFailureType.refreshSessionSuperseded,
            ),
          ),
        ),
      );

      // 5. Verify active state resets normally: a later rev11 request can refresh
      testAdapter.handler = (options) async {
        if (options.headers['Authorization'] == 'Bearer token-rev11') {
          return MockHttpClientAdapter.json(
            {'code': 'AUTH_TOKEN_EXPIRED', 'message': 'Token expired'},
            401,
          );
        }
        if (options.headers['Authorization'] == 'Bearer token-rev12') {
          return MockHttpClientAdapter.json({'data': 'success-rev12'}, 200);
        }
        return MockHttpClientAdapter.json({}, 400);
      };

      final fC = testDio.get<Map<String, dynamic>>('/api/v1/reqC');
      await pumpEventQueue();
      expect(refreshCalls, 2); // rev11 refresh initiated successfully

      revHolder.setAccessToken('token-rev12');
      rev11Completer.complete(
        const SessionRevisionTransition(fromRevision: 11, toRevision: 12),
      );

      final rC = await fC;
      expect(rC.data?['data'], 'success-rev12');
    });

    // Requirement: Public Endpoint onError Exclusion
    test('public endpoint onError exclusion: /api/v1/auth/test and /api/v1/health never refresh or retry on 401 AUTH_TOKEN_EXPIRED', () async {
      adapter.handler = (options) async => MockHttpClientAdapter.json(
        {'code': 'AUTH_TOKEN_EXPIRED', 'message': 'Artificial error'},
        401,
      );

      // 1. /api/v1/auth/test
      await expectLater(
        dio.post<void>('/api/v1/auth/test'),
        throwsA(
          isA<DioException>().having(
            (e) => (e.response?.data as Map)['code'],
            'code',
            'AUTH_TOKEN_EXPIRED',
          ),
        ),
      );

      // 2. /api/v1/health
      await expectLater(
        dio.get<void>('/api/v1/health'),
        throwsA(
          isA<DioException>().having(
            (e) => (e.response?.data as Map)['code'],
            'code',
            'AUTH_TOKEN_EXPIRED',
          ),
        ),
      );

      expect(refreshCallCount, 0);
      expect(adapter.requests, hasLength(2));
    });
  });
}

class RecordedRequest {
  final String method;
  final String path;
  final Map<String, dynamic> headers;
  final Map<String, dynamic> queryParameters;
  final dynamic data;

  RecordedRequest({
    required this.method,
    required this.path,
    required Map<String, dynamic> headers,
    required Map<String, dynamic> queryParameters,
    required this.data,
  })  : headers = Map<String, dynamic>.from(headers),
        queryParameters = Map<String, dynamic>.from(queryParameters);
}

class MockHttpClientAdapter implements HttpClientAdapter {
  final List<RecordedRequest> requests = [];
  Future<ResponseBody> Function(RequestOptions options)? handler;

  static ResponseBody json(dynamic data, [int statusCode = 200]) {
    return ResponseBody.fromString(
      data is String ? data : jsonEncode(data),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(
      RecordedRequest(
        method: options.method,
        path: options.path,
        headers: options.headers,
        queryParameters: options.queryParameters,
        data: options.data,
      ),
    );
    if (handler != null) {
      return handler!(options);
    }
    return json('{}', 200);
  }

  @override
  void close({bool force = false}) {}
}
