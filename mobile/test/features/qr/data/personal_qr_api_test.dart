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
