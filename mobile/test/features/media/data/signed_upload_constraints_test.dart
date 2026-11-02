import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/media/data/media_upload_service.dart';

// Entirely synthetic; adapter consumes streams locally and never opens a socket.
const _signedUrl =
    'https://storage.invalid/synthetic?'
    'X-Amz-SignedHeaders=content-length%3Bcontent-type%3Bhost%3Bif-none-match';
Map<String, String> _headers([int length = 3]) => {
  'Content-Type': 'image/png',
  'Content-Length': '$length',
  'If-None-Match': '*',
};
Map<String, dynamic> _target(
  Map<String, String> headers, [
  String url = _signedUrl,
]) => {
  'storageKey': 'synthetic/key',
  'uploadUrl': url,
  'expiresAt': '2030-01-01T00:10:00Z',
  'requiredHeaders': headers,
};

void main() {
  for (final length in [1, 3, 1024]) {
    test('bytes length $length retained by actual Dio transformer', () async {
      final harness = _Harness(_headers(length));
      final key = await harness.image(length);
      expect(key, 'synthetic/key');
      expect(harness.put.bytes, length);
      expect(harness.put.header('content-length'), '$length');
      expect(harness.put.headerCount('content-length'), 1);
      expect(harness.put.header('if-none-match'), '*');
      expect(harness.put.header('authorization'), isNull);
      expect(harness.put.request!.followRedirects, isFalse);
    });
  }
  for (final name in ['Content-Length', 'If-None-Match']) {
    test('missing $name fails before PUT', () async {
      final harness = _Harness(_headers()..remove(name));
      await expectLater(harness.image(3), throwsA(isA<MediaUploadException>()));
      expect(harness.put.calls, 0);
    });
    test('case-insensitive duplicate $name rejected', () async {
      final headers = _headers();
      headers[name.toLowerCase()] = headers[name]!;
      final harness = _Harness(headers);
      await expectLater(harness.image(3), throwsA(isA<MediaUploadException>()));
      expect(harness.put.calls, 0);
    });
  }
  for (final value in ['2', '4', '03', '-1', '3,3']) {
    test('invalid declared length $value rejected before PUT', () async {
      final harness = _Harness(_headers()..['Content-Length'] = value);
      await expectLater(harness.image(3), throwsA(isA<MediaUploadException>()));
      expect(harness.put.calls, 0);
    });
  }
  test('modified If-None-Match rejected', () async {
    final harness = _Harness(_headers()..['If-None-Match'] = 'different');
    await expectLater(harness.image(3), throwsA(isA<MediaUploadException>()));
    expect(harness.put.calls, 0);
  });
  test(
    'constraints cannot be invented outside actual signed headers',
    () async {
      final harness = _Harness(
        _headers(),
        url: 'https://storage.invalid/synthetic',
      );
      await expectLater(harness.image(3), throwsA(isA<MediaUploadException>()));
      expect(harness.put.calls, 0);
    },
  );
  test('requiredHeaders cannot carry backend Authorization', () async {
    final harness = _Harness(
      _headers()..['authorization'] = 'synthetic-bearer',
    );
    await expectLater(harness.image(3), throwsA(isA<MediaUploadException>()));
    expect(harness.put.calls, 0);
  });
  test(
    'case-insensitive headers accepted and default bearer removed',
    () async {
      final harness = _Harness({
        for (final e in _headers().entries) e.key.toLowerCase(): e.value,
      });
      await harness.image(3);
      expect(harness.put.header('authorization'), isNull);
    },
  );
  test(
    'exact stream length uploads chunks without whole-file buffering',
    () async {
      final harness = _Harness(_headers());
      expect(
        await harness.stream([
          [1],
          [2, 3],
        ]),
        'synthetic/key',
      );
      expect(harness.put.bytes, 3);
      expect(harness.put.header('content-length'), '3');
      expect(harness.put.headerCount('content-length'), 1);
      expect(harness.put.header('authorization'), isNull);
    },
  );
  for (final chunks in <List<List<int>>>[
    [
      [1, 2],
    ],
    [
      [1, 2],
      [3, 4],
    ],
  ]) {
    test(
      'stream payload length mismatch ${chunks.last.length}/${chunks.length}',
      () async {
        final harness = _Harness(_headers());
        await expectLater(
          harness.stream(chunks),
          throwsA(isA<MediaUploadPendingException>()),
        );
        expect(harness.put.calls, 1);
        expect(harness.put.bytes, lessThanOrEqualTo(3));
        expect(
          harness.api.calls,
          1,
        ); // No automatic HEAD/confirm or PUT replay.
      },
    );
  }
  for (final stream in [false, true]) {
    for (final status in [412, 500, null]) {
      test(
        '${stream ? 'stream' : 'bytes'} ambiguous PUT $status never retried',
        () async {
          final harness = _Harness(_headers(), status: status);
          try {
            if (stream) {
              await harness.stream([
                [1, 2, 3],
              ]);
            } else {
              await harness.image(3);
            }
            fail('Expected safe pending outcome');
          } on MediaUploadPendingException catch (error) {
            expect(error.storageKey, 'synthetic/key');
            expect(
              error.code,
              status == 412 ? 'upload_conflict' : 'upload_outcome_unknown',
            );
            expect(error.toString(), isNot(contains('storage.invalid')));
            expect(error.toString(), isNot(contains('X-Amz')));
          }
          expect(harness.put.calls, 1);
          expect(harness.api.calls, 1);
        },
      );
    }
  }
  test('non-constrained legacy stream keeps existing contract', () async {
    final harness = _Harness({
      'Content-Type': 'video/mp4',
    }, url: 'https://storage.invalid/synthetic');
    expect(
      await harness.stream([
        [1, 2, 3],
      ]),
      'synthetic/key',
    );
    expect(harness.put.header('content-length'), '3');
    expect(harness.put.header('if-none-match'), isNull);
    expect(harness.put.request!.followRedirects, isTrue);
  });
}

class _Harness {
  final _Presign api;
  final _Put put;
  late final MediaUploadService service;
  _Harness(
    Map<String, String> headers, {
    String url = _signedUrl,
    int? status = 200,
  }) : api = _Presign(_target(headers, url)),
       put = _Put(status) {
    service = MediaUploadService(
      apiDio: Dio(
        BaseOptions(
          baseUrl: 'https://api.invalid',
          headers: {'Authorization': 'synthetic-session'},
        ),
      )..httpClientAdapter = api,
      directUploadDio: Dio(
        BaseOptions(headers: {'Authorization': 'synthetic-default'}),
      )..httpClientAdapter = put,
    );
  }
  Future<String> image(int length) => service.uploadImage(
    category: 'AVATAR',
    fileName: 'synthetic.png',
    contentType: 'image/png',
    bytes: Uint8List(length),
  );
  Future<String> stream(List<List<int>> chunks) => service.uploadStream(
    category: 'MOMENT_IMAGE',
    contextId: 'synthetic-group',
    fileName: 'synthetic.png',
    contentType: 'image/png',
    length: 3,
    openRead: () => Stream.fromIterable(chunks),
  );
}

class _Presign implements HttpClientAdapter {
  final Map<String, dynamic> target;
  int calls = 0;
  _Presign(this.target);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromString(
      jsonEncode(target),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Put implements HttpClientAdapter {
  final int? status;
  int calls = 0, bytes = 0;
  RequestOptions? request;
  _Put(this.status);
  Object? header(String name) {
    for (final entry in request!.headers.entries) {
      if (entry.key.toLowerCase() == name) return entry.value;
    }
    return null;
  }

  int headerCount(String name) =>
      request!.headers.keys.where((key) => key.toLowerCase() == name).length;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    request = options;
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes += chunk.length;
      }
    }
    if (status == null) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: 'synthetic transport failure; must not escape',
      );
    }
    return ResponseBody.fromString('', status!);
  }

  @override
  void close({bool force = false}) {}
}
