import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/access_token_holder.dart';
import 'package:mobile/core/network/api_config.dart';
import 'package:mobile/core/network/auth_interceptor.dart';
import 'package:mobile/core/network/dio_client.dart';

void main() {
  group('DioClient and AuthInterceptor', () {
    late AccessTokenHolder tokenHolder;
    late RecordingAdapter adapter;
    late DioClient client;

    setUp(() {
      tokenHolder = AccessTokenHolder();
      adapter = RecordingAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      client = DioClient(
        apiConfig: ApiConfig(baseUrl: 'https://api.example.test/'),
        accessTokenHolder: tokenHolder,
        dio: dio,
      );
    });

    test(
      'configures the normalized base URL and installs its interceptor once',
      () {
        expect(client.dio.options.baseUrl, 'https://api.example.test');
        expect(client.dio.options.contentType, Headers.jsonContentType);
        expect(
          client.dio.interceptors.whereType<AuthInterceptor>(),
          hasLength(1),
        );

        DioClient(
          apiConfig: ApiConfig(baseUrl: 'https://api.example.test'),
          accessTokenHolder: tokenHolder,
          dio: client.dio,
        );

        expect(
          client.dio.interceptors.whereType<AuthInterceptor>(),
          hasLength(1),
        );
      },
    );

    test('leaves protected request unchanged when no token exists', () async {
      await client.dio.get<void>('/api/v1/me');

      expect(adapter.requests.single.headers, isNot(contains('Authorization')));
    });

    test('attaches a Bearer token to a protected request', () async {
      tokenHolder.setAccessToken('access-token');

      await client.dio.get<void>('/api/v1/me');

      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer access-token',
      );
    });

    test('excludes all current public auth endpoints and health', () async {
      tokenHolder.setAccessToken('access-token');

      await client.dio.post<void>('/api/v1/auth/login');
      await client.dio.post<void>('/api/v1/auth/register');
      await client.dio.post<void>('/api/v1/auth/resend-verification');
      await client.dio.get<void>('/api/v1/health');

      expect(adapter.requests, hasLength(4));
      for (final request in adapter.requests) {
        expect(request.headers, isNot(contains('Authorization')));
      }
    });

    test('performs one request without retry or refresh behavior', () async {
      tokenHolder.setAccessToken('access-token');

      await client.dio.get<void>('/api/v1/me');

      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.path, '/api/v1/me');
    });

    test('DioClient.raw configures identical options with zero interceptors', () {
      final rawClient = DioClient.raw(
        apiConfig: ApiConfig(baseUrl: 'https://api.example.test/'),
      );

      expect(rawClient.dio.options.baseUrl, 'https://api.example.test');
      expect(rawClient.dio.options.contentType, Headers.jsonContentType);
      expect(rawClient.dio.options.connectTimeout, const Duration(seconds: 15));
      expect(rawClient.dio.options.sendTimeout, const Duration(seconds: 15));
      expect(rawClient.dio.options.receiveTimeout, const Duration(seconds: 30));
      expect(rawClient.dio.options.headers['Accept'], 'application/json');
      expect(rawClient.dio.interceptors.isEmpty, isTrue);

      // Strips AuthInterceptor if passed an existing dio containing one
      final clientWithAuth = DioClient.raw(
        apiConfig: ApiConfig(baseUrl: 'https://api.example.test/'),
        dio: Dio()..interceptors.add(AuthInterceptor(tokenHolder)),
      );
      expect(clientWithAuth.dio.interceptors.isEmpty, isTrue);

      // Also strips arbitrary non-auth interceptors
      final customAdapter = RecordingAdapter();
      final clientWithArbitrary = DioClient.raw(
        apiConfig: ApiConfig(baseUrl: 'https://api.example.test/'),
        dio: Dio()
          ..httpClientAdapter = customAdapter
          ..interceptors.addAll([
            InterceptorsWrapper(
              onRequest: (options, handler) => handler.next(options),
            ),
            LogInterceptor(),
          ]),
      );
      expect(clientWithArbitrary.dio.interceptors.isEmpty, isTrue);
      expect(identical(clientWithArbitrary.dio.httpClientAdapter, customAdapter), isTrue);
    });
  });
}

class RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
