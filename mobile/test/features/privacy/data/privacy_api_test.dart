import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/privacy/data/privacy_api.dart';
import 'package:mobile/features/privacy/data/privacy_models.dart';

void main() {
  late _RecordingAdapter adapter;
  late PrivacyApi api;

  setUp(() {
    adapter = _RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            options.headers['Authorization'] = 'Bearer current-access-token';
            handler.next(options);
          },
        ),
      )
      ..httpClientAdapter = adapter;
    api = PrivacyApi(dio);
  });

  test(
    'GETs the current user privacy settings with the authenticated client',
    () async {
      final settings = await api.getPrivacySettings();

      expect(adapter.request.method, 'GET');
      expect(adapter.request.path, '/api/v1/me/privacy');
      expect(
        adapter.request.headers['Authorization'],
        'Bearer current-access-token',
      );
      expect(settings.discoverByUsername, isTrue);
      expect(settings.dmPolicy, DmPolicy.everyone);
    },
  );

  test('PATCHes only explicit privacy changes and preserves false', () async {
    await api.updatePrivacySettings(
      const UpdatePrivacySettingsRequest(
        discoverByPhone: false,
        dmPolicy: DmPolicy.friendsOnly,
      ),
    );

    expect(adapter.request.method, 'PATCH');
    expect(adapter.request.path, '/api/v1/me/privacy');
    expect(
      adapter.request.headers['Authorization'],
      'Bearer current-access-token',
    );
    expect(adapter.request.data, {
      'discoverByPhone': false,
      'dmPolicy': 'FRIENDS_ONLY',
    });
  });
}

Map<String, dynamic> _privacyJson() => {
  'discoverByUsername': true,
  'discoverByQr': true,
  'discoverByEmail': false,
  'discoverByPhone': false,
  'dmPolicy': 'EVERYONE',
  'friendRequestPolicy': 'EVERYONE',
  'showOnlineStatus': true,
  'showLastSeen': true,
};

class _RecordingAdapter implements HttpClientAdapter {
  late RequestOptions request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode(_privacyJson()),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
