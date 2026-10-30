import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/media/data/media_upload_service.dart';

void main() {
  final png = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 1, 2]);
  test('fresh contextual authorization on every save; no bearer sent to storage; exact original bytes', () async {
    final api = _Adapter(
      (_) => ResponseBody.fromString(
        jsonEncode({'url': 'https://storage.test/private'}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    final storage = _Adapter((_) => ResponseBody.fromBytes(png, 200));
    final service = MediaUploadService(
      apiDio: Dio(
        BaseOptions(
          baseUrl: 'https://api.test',
          headers: {'Authorization': 'Bearer fake-test'},
        ),
      )..httpClientAdapter = api,
      directUploadDio: Dio()..httpClientAdapter = storage,
    );
    for (var i = 0; i < 2; i++) {
      final image = await service.downloadImage(
        'chat-attachment/conversation/object',
      );
      expect(image.bytes, orderedEquals(png));
      expect(image.contentType, 'image/png');
    }
    expect(api.requests, hasLength(2));
    expect(
      api.requests.first.queryParameters['storageKey'],
      'chat-attachment/conversation/object',
    );
    expect(storage.requests.first.headers['Authorization'], isNull);
    expect(storage.requests.first.followRedirects, isFalse);
  });
  test('rejects empty, unsupported and oversized bytes', () {
    for (final bytes in [
      Uint8List(0),
      Uint8List.fromList([1, 2]),
      Uint8List(MediaUploadService.maxImageBytes + 1),
    ]) {
      expect(
        () => DownloadedMediaImage.fromBytes(bytes),
        throwsA(isA<MediaUploadException>()),
      );
    }
    expect(
      DownloadedMediaImage.fromBytes(Uint8List.fromList([255, 216, 255]))
          .contentType,
      'image/jpeg',
    );
    expect(
      DownloadedMediaImage.fromBytes(
        Uint8List.fromList([82, 73, 70, 70, 0, 0, 0, 0, 87, 69, 66, 80]),
      ).contentType,
      'image/webp',
    );
  });
  test('denied authorization never contacts storage', () async {
    final api = _Adapter((_) => ResponseBody.fromString('{}', 403));
    final storage = _Adapter((_) => ResponseBody.fromBytes(png, 200));
    final service = MediaUploadService(
      apiDio: Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = api,
      directUploadDio: Dio()..httpClientAdapter = storage,
    );
    await expectLater(
      service.downloadImage('private'),
      throwsA(isA<MediaUploadException>()),
    );
    expect(storage.requests, isEmpty);
  });
  test('oversized stream without declared length is bounded', () async {
    final api = _Adapter(
      (_) => ResponseBody.fromString(
        '{"url":"https://storage.test/private"}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    final storage = _Adapter(
      (_) => ResponseBody(
        Stream.fromIterable([
          Uint8List(MediaUploadService.maxImageBytes),
          Uint8List(1),
        ]),
        200,
      ),
    );
    final service = MediaUploadService(
      apiDio: Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = api,
      directUploadDio: Dio()..httpClientAdapter = storage,
    );
    await expectLater(
      service.downloadImage('private'),
      throwsA(isA<MediaUploadException>()),
    );
  });
}

class _Adapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions) respond;
  final requests = <RequestOptions>[];
  _Adapter(this.respond);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}
