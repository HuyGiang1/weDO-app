import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/profile/data/profile_api.dart';
import 'package:mobile/features/profile/data/profile_models.dart';

void main() {
  const json = {
    'id': 'target-id',
    'username': 'maya_lin',
    'displayName': null,
    'avatarStorageKey': null,
    'bio': null,
  };

  test(
    'decodes exactly the safe public profile DTO including nullable fields',
    () {
      final profile = PublicUserProfile.fromJson(json);
      expect(profile.id, 'target-id');
      expect(profile.username, 'maya_lin');
      expect(profile.displayName, isNull);
      expect(profile.avatarStorageKey, isNull);
      expect(profile.bio, isNull);
    },
  );

  test(
    'GETs the public profile endpoint and maps Dio failures safely',
    () async {
      final adapter = _Adapter(json, 200);
      final api = ProfileApi(Dio()..httpClientAdapter = adapter);
      final profile = await api.getPublicProfile('target-id');
      expect(adapter.request.path, '/api/v1/users/target-id');
      expect(profile.username, 'maya_lin');

      final failing = ProfileApi(
        Dio()
          ..httpClientAdapter = _Adapter({'code': 'RESOURCE_NOT_FOUND'}, 404),
      );
      await expectLater(
        failing.getPublicProfile('missing'),
        throwsA(isA<ApiException>()),
      );
    },
  );
}

class _Adapter implements HttpClientAdapter {
  final Object body;
  final int status;
  late RequestOptions request;
  _Adapter(this.body, this.status);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
