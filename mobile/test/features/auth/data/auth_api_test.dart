import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_failure.dart';
import 'package:mobile/features/auth/data/models/auth_models.dart';

void main() {
  late RecordingAdapter adapter;
  late RecordingAdapter refreshAdapter;
  late AuthApi api;
  setUp(() {
    adapter = RecordingAdapter();
    refreshAdapter = RecordingAdapter();
    api = AuthApi(
      Dio(BaseOptions(baseUrl: 'https://test'))..httpClientAdapter = adapter,
      refreshDio:
          Dio(BaseOptions(baseUrl: 'https://test'))..httpClientAdapter = refreshAdapter,
    );
  });
  test('uses exact public-auth methods, bodies, headers, paths, and parses responses', () async {
    adapter.responses['/api/v1/auth/register'] = {
      'userId': 'u',
      'email': 'a@b.c',
      'status': 'PENDING_VERIFICATION',
      'nextStep': 'VERIFY_EMAIL',
    };
    adapter.responses['/api/v1/auth/verify-email'] = {
      'userId': 'u',
      'status': 'ACTIVE',
      'emailVerifiedAt': '2026-01-01T00:00:00Z',
      'nextStep': 'COMPLETE_PROFILE',
      'profileCompletionToken': 'pct',
    };
    adapter.responses['/api/v1/auth/resend-verification'] = {
      'userId': 'u',
      'cooldownSeconds': 60,
    };
    adapter.responses['/api/v1/auth/usernames/a%20b/availability'] = {
      'username': 'a b',
      'available': true,
    };
    adapter.responses['/api/v1/auth/complete-profile'] = {
      'userId': 'u',
      'username': 'name',
      'displayName': 'Name',
      'status': 'ACTIVE',
      'nextStep': 'LOGIN',
    };
    adapter.responses['/api/v1/auth/login'] = {
      'userId': 'u',
      'status': 'ACTIVE',
      'nextStep': 'AUTHENTICATED',
      'accessToken': 'a',
      'refreshToken': 'r',
      'tokenType': 'Bearer',
      'accessTokenExpiresAt': '2026-01-01T00:00:00Z',
      'user': {
        'id': 'u',
        'email': 'a@b.c',
        'username': 'name',
        'displayName': 'Name',
      },
    };
    adapter.responses['/api/v1/auth/forgot-password'] = {'message': 'neutral'};
    adapter.responses['/api/v1/me'] = {
      'id': 'u',
      'email': 'a@b.c',
      'status': 'ACTIVE',
      'emailVerified': true,
      'username': null,
      'phone': null,
      'displayName': null,
      'avatarStorageKey': null,
      'bio': null,
    };
    expect((await api.register(email: 'a@b.c', password: 'raw')).userId, 'u');
    await api.verifyEmail(userId: 'u', code: '012345');
    await api.resendVerification('u');
    await api.checkUsernameAvailability('a b');
    await api.completeProfile(
      profileCompletionToken: 'pct',
      username: 'name',
      displayName: 'Name',
      bio: null,
      avatarStorageKey: null,
    );
    expect(
      await api.login(email: 'a@b.c', password: 'raw', deviceName: 'device'),
      isA<AuthenticatedSession>(),
    );
    await api.forgotPassword('a@b.c');
    await api.resetPassword(
      email: 'a@b.c',
      code: '001234',
      newPassword: ' raw ',
    );
    await api.logout('refresh');
    expect((await api.getCurrentUser()).id, 'u');
    expect(adapter.byPath('/api/v1/auth/register').data, {
      'email': 'a@b.c',
      'password': 'raw',
    });
    expect(adapter.byPath('/api/v1/auth/verify-email').data, {
      'userId': 'u',
      'code': '012345',
    });
    expect(
      adapter.byPath('/api/v1/auth/usernames/a%20b/availability').method,
      'GET',
    );
    expect(adapter.byPath('/api/v1/auth/complete-profile').data, {
      'profileCompletionToken': 'pct',
      'username': 'name',
      'displayName': 'Name',
      'bio': null,
      'avatarStorageKey': null,
    });
    expect(
      adapter.byPath('/api/v1/auth/login').headers['X-Device-Name'],
      'device',
    );
    expect(adapter.byPath('/api/v1/auth/reset-password').data, {
      'email': 'a@b.c',
      'code': '001234',
      'newPassword': ' raw ',
    });
  });
  test('maps backend, malformed, and transport Dio failures safely', () async {
    adapter.status = 400;
    adapter.responses['/api/v1/auth/register'] = {
      'code': 'EMAIL_ALREADY_EXISTS',
      'message': 'exists',
      'errors': {'email': 'taken'},
      'requestId': 'r',
    };
    await expectLater(
      api.register(email: 'x', password: 'p'),
      throwsA(isA<ApiException>()),
    );
    adapter.throwConnection = true;
    await expectLater(
      api.register(email: 'x', password: 'p'),
      throwsA(isA<ApiException>()),
    );
  });

  test('refreshToken uses dedicated refresh transport without auth header and parses response', () async {
    refreshAdapter.responses['/api/v1/auth/refresh'] = {
      'accessToken': '  new-access  ',
      'refreshToken': '  new-refresh  ',
      'tokenType': 'Bearer',
      'accessTokenExpiresAt': '2026-06-01T12:00:00Z',
      'refreshTokenExpiresAt': '2026-06-08T12:00:00Z',
    };

    final result = await api.refreshToken('current-refresh-token');

    expect(result.accessToken, '  new-access  ');
    expect(result.refreshToken, '  new-refresh  ');
    expect(result.tokenType, 'Bearer');
    expect(result.accessTokenExpiresAt, DateTime.parse('2026-06-01T12:00:00Z'));
    expect(result.refreshTokenExpiresAt, DateTime.parse('2026-06-08T12:00:00Z'));

    // Verify isolated refresh transport was used
    expect(refreshAdapter.requests.length, 1);
    final request = refreshAdapter.requests.first;
    expect(request.path, '/api/v1/auth/refresh');
    expect(request.method, 'POST');
    expect(request.data, {'refreshToken': 'current-refresh-token'});
    expect(request.headers['Authorization'], isNull);
    expect(request.headers['X-Device-Name'], isNull);

    // Verify primary transport was NOT touched
    expect(adapter.requests.any((r) => r.path == '/api/v1/auth/refresh'), isFalse);
  });

  test('refreshToken throws FormatException on malformed success payloads', () async {
    // Missing token
    refreshAdapter.responses['/api/v1/auth/refresh'] = {
      'accessToken': 'access',
      'tokenType': 'Bearer',
      'accessTokenExpiresAt': '2026-06-01T12:00:00Z',
      'refreshTokenExpiresAt': '2026-06-08T12:00:00Z',
    };
    await expectLater(
      api.refreshToken('token'),
      throwsA(isA<FormatException>()),
    );

    // Blank token
    refreshAdapter.responses['/api/v1/auth/refresh'] = {
      'accessToken': '   ',
      'refreshToken': 'refresh',
      'tokenType': 'Bearer',
      'accessTokenExpiresAt': '2026-06-01T12:00:00Z',
      'refreshTokenExpiresAt': '2026-06-08T12:00:00Z',
    };
    await expectLater(
      api.refreshToken('token'),
      throwsA(isA<FormatException>()),
    );

    // Invalid tokenType
    refreshAdapter.responses['/api/v1/auth/refresh'] = {
      'accessToken': 'access',
      'refreshToken': 'refresh',
      'tokenType': 'Basic',
      'accessTokenExpiresAt': '2026-06-01T12:00:00Z',
      'refreshTokenExpiresAt': '2026-06-08T12:00:00Z',
    };
    await expectLater(
      api.refreshToken('token'),
      throwsA(isA<FormatException>()),
    );

    // Malformed date
    refreshAdapter.responses['/api/v1/auth/refresh'] = {
      'accessToken': 'access',
      'refreshToken': 'refresh',
      'tokenType': 'Bearer',
      'accessTokenExpiresAt': 'invalid-date',
      'refreshTokenExpiresAt': '2026-06-08T12:00:00Z',
    };
    await expectLater(
      api.refreshToken('token'),
      throwsA(isA<FormatException>()),
    );

    // Wrong type: accessToken: 123
    refreshAdapter.responses['/api/v1/auth/refresh'] = {
      'accessToken': 123,
      'refreshToken': 'refresh',
      'tokenType': 'Bearer',
      'accessTokenExpiresAt': '2026-06-01T12:00:00Z',
      'refreshTokenExpiresAt': '2026-06-08T12:00:00Z',
    };
    await expectLater(
      api.refreshToken('token'),
      throwsA(isA<FormatException>()),
    );

    // Wrong type: refreshToken: {}
    refreshAdapter.responses['/api/v1/auth/refresh'] = {
      'accessToken': 'access',
      'refreshToken': <String, dynamic>{},
      'tokenType': 'Bearer',
      'accessTokenExpiresAt': '2026-06-01T12:00:00Z',
      'refreshTokenExpiresAt': '2026-06-08T12:00:00Z',
    };
    await expectLater(
      api.refreshToken('token'),
      throwsA(isA<FormatException>()),
    );

    // Wrong type: tokenType: 123
    refreshAdapter.responses['/api/v1/auth/refresh'] = {
      'accessToken': 'access',
      'refreshToken': 'refresh',
      'tokenType': 123,
      'accessTokenExpiresAt': '2026-06-01T12:00:00Z',
      'refreshTokenExpiresAt': '2026-06-08T12:00:00Z',
    };
    await expectLater(
      api.refreshToken('token'),
      throwsA(isA<FormatException>()),
    );

    // Wrong type: accessTokenExpiresAt: 123
    refreshAdapter.responses['/api/v1/auth/refresh'] = {
      'accessToken': 'access',
      'refreshToken': 'refresh',
      'tokenType': 'Bearer',
      'accessTokenExpiresAt': 123,
      'refreshTokenExpiresAt': '2026-06-08T12:00:00Z',
    };
    await expectLater(
      api.refreshToken('token'),
      throwsA(isA<FormatException>()),
    );

    // Wrong type: refreshTokenExpiresAt: []
    refreshAdapter.responses['/api/v1/auth/refresh'] = {
      'accessToken': 'access',
      'refreshToken': 'refresh',
      'tokenType': 'Bearer',
      'accessTokenExpiresAt': '2026-06-01T12:00:00Z',
      'refreshTokenExpiresAt': <dynamic>[],
    };
    await expectLater(
      api.refreshToken('token'),
      throwsA(isA<FormatException>()),
    );
  });

  test('refreshToken maps REFRESH_TOKEN_INVALID and remote errors', () async {
    refreshAdapter.status = 401;
    refreshAdapter.responses['/api/v1/auth/refresh'] = {
      'code': 'REFRESH_TOKEN_INVALID',
      'message': 'Invalid refresh token.',
    };
    try {
      await api.refreshToken('token');
      fail('Expected ApiException');
    } on ApiException catch (e) {
      expect(e.statusCode, 401);
      expect(e.code, 'REFRESH_TOKEN_INVALID');
      expect(AuthFailure.fromApi(e).type, AuthFailureType.refreshTokenInvalid);
    }
  });
}

class RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final responses = <String, dynamic>{};
  int status = 200;
  bool throwConnection = false;
  RequestOptions byPath(String p) => requests.firstWhere((r) => r.path == p);
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    requests.add(o);
    if (throwConnection) {
      throw DioException(
        requestOptions: o,
        type: DioExceptionType.connectionError,
      );
    }
    return ResponseBody.fromString(
      jsonEncode(responses[o.path] ?? {}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
