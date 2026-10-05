import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/media/data/media_upload_service.dart';

void main() {
  test(
    'presigns scoped group avatar then uploads bytes with required headers',
    () async {
      final apiAdapter = _ApiAdapter();
      final uploadAdapter = _UploadAdapter();
      final service = MediaUploadService(
        apiDio: Dio(BaseOptions(baseUrl: 'https://api.test'))
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                options.headers['Authorization'] = 'Bearer session-token';
                handler.next(options);
              },
            ),
          )
          ..httpClientAdapter = apiAdapter,
        directUploadDio: Dio()..httpClientAdapter = uploadAdapter,
      );
      final bytes = Uint8List.fromList([1, 2, 3]);

      final key = await service.uploadImage(
        category: 'GROUP_AVATAR',
        fileName: 'group.png',
        contentType: 'image/png',
        bytes: bytes,
        contextId: 'group-123',
      );

      expect(key, 'group-avatar/group-123/object-uuid');
      expect(apiAdapter.request.path, '/api/v1/uploads/presign');
      expect(apiAdapter.request.method, 'POST');
      expect(
        apiAdapter.request.headers['Authorization'],
        'Bearer session-token',
      );
      expect(apiAdapter.request.data, {
        'category': 'GROUP_AVATAR',
        'fileName': 'group.png',
        'contentType': 'image/png',
        'fileSize': 3,
        'contextId': 'group-123',
      });
      expect(
        uploadAdapter.request.uri,
        Uri.parse('http://127.0.0.1:9000/upload'),
      );
      expect(uploadAdapter.request.headers['Authorization'], isNull);
      expect(uploadAdapter.request.headers['Content-Type'], 'image/png');
      expect(uploadAdapter.request.headers['x-amz-meta-declared-size'], '3');
      expect(uploadAdapter.request.data, bytes);
    },
  );

  test('profile presign omits contextId', () async {
    final apiAdapter = _ApiAdapter();
    final service = MediaUploadService(
      apiDio: Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = apiAdapter,
      directUploadDio: Dio()..httpClientAdapter = _UploadAdapter(),
    );

    await service.uploadImage(
      category: 'AVATAR',
      fileName: 'profile.webp',
      contentType: 'image/webp',
      bytes: Uint8List.fromList([4]),
    );

    expect(apiAdapter.request.data, {
      'category': 'AVATAR',
      'fileName': 'profile.webp',
      'contentType': 'image/webp',
      'fileSize': 1,
    });
  });
}

class _ApiAdapter implements HttpClientAdapter {
  late RequestOptions request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode({
        'storageKey': 'group-avatar/group-123/object-uuid',
        'uploadUrl': 'http://127.0.0.1:9000/upload',
        'expiresAt': '2030-01-01T00:10:00Z',
        'requiredHeaders': {
          'Content-Type': 'image/png',
          'x-amz-meta-declared-size': '3',
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _UploadAdapter implements HttpClientAdapter {
  late RequestOptions request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString('', 200);
  }

  @override
  void close({bool force = false}) {}
}
