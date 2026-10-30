import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/qr/data/personal_qr_api.dart';

void main() {
  test('uses authenticated Dio and the exact personal QR API path', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://wedo.test'));
    String? requestedPath;
    dio.httpClientAdapter = _Adapter((options) async {
      requestedPath = options.path;
      return ResponseBody.fromString(
        '{"deepLink":"wedo://user/id"}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    });
    final result = await PersonalQrApi(dio).getPersonalQr();
    expect(requestedPath, '/api/v1/me/qr');
    expect(result.deepLink, 'wedo://user/id');
  });

  test('resolves scanned QR deep links via POST /api/v1/users/qr/resolve', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://wedo.test'));
    String? requestedPath;
    String? requestedMethod;
    Object? requestData;
    dio.httpClientAdapter = _Adapter((options) async {
      requestedPath = options.path;
      requestedMethod = options.method;
      requestData = options.data;
      return ResponseBody.fromString(
        '{"id":"550e8400-e29b-41d4-a716-446655440000","username":"maya","displayName":"Maya"}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    });
    final profile = await PersonalQrApi(dio).resolveQr(
      'https://wedo-3304c.web.app/u/550e8400-e29b-41d4-a716-446655440000',
    );
    expect(requestedPath, '/api/v1/users/qr/resolve');
    expect(requestedMethod, 'POST');
    expect(requestData, {
      'deepLink':
          'https://wedo-3304c.web.app/u/550e8400-e29b-41d4-a716-446655440000',
    });
    expect(profile.id, '550e8400-e29b-41d4-a716-446655440000');
    expect(profile.username, 'maya');
  });
}

class _Adapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions) handler;
  _Adapter(this.handler);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);
  @override
  void close({bool force = false}) {}
}
