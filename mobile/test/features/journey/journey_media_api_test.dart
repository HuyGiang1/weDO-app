import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/journey/data/journey_api.dart';
import 'package:mobile/features/community/data/community_api.dart';
import 'package:mobile/core/network/api_exception.dart';

class _MediaAdapter implements HttpClientAdapter {
  final paths = <String>[];
  int status = 200;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body,
      Future<void>? cancelFuture) async {
    paths.add(options.path);
    return ResponseBody.fromString(
      status == 200 ? '{"url":"http://media.invalid/private-image"}' : '{"message":"Denied"}',
      status,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }
  @override
  void close({bool force = false}) {}
}

void main() {
  late Dio dio;
  late _MediaAdapter adapter;
  setUp(() {
    adapter = _MediaAdapter();
    dio = Dio(BaseOptions(baseUrl: 'http://api.invalid'))..httpClientAdapter = adapter;
  });
  tearDown(() => dio.close());
  test('check-in images use canonical Moment authorization, never Community', () async {
    expect(await JourneyApi(dio).mediaUrl('moment-image'), 'http://media.invalid/private-image');
    expect(adapter.paths, ['/api/v1/moment-media/moment-image/access']);
  });
  test('Task proof retains Task authorization; Community retains Community scope', () async {
    await EvidenceMediaApi(dio, 'task').mediaUrl('proof');
    await CommunityApi(dio).mediaUrl('public-image');
    expect(adapter.paths, [
      '/api/v1/tasks/task/evidence/media/proof/access',
      '/api/v1/community/media/public-image/access',
    ]);
  });
  test('denied check-in does not fall back to another media domain', () async {
    adapter.status = 403;
    await expectLater(JourneyApi(dio).mediaUrl('denied'), throwsA(isA<ApiException>()));
    expect(adapter.paths, ['/api/v1/moment-media/denied/access']);
  });
}
