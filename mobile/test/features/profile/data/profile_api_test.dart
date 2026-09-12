import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile/data/profile_api.dart';
import 'package:mobile/features/profile/data/profile_models.dart';

void main() {
  late _RecordingAdapter adapter;
  late ProfileApi api;

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
    api = ProfileApi(dio);
  });

  test('PATCHes the allow-listed profile payload and parses MyProfileResponse', () async {
    adapter.response = _profileJson(
      displayName: 'Updated',
      bio: 'New bio',
      phone: '+84987654321',
    );

    final user = await api.updateProfile(
      const UpdateProfileRequest(
        displayName: 'Updated',
        bio: 'New bio',
        phone: '+84987654321',
        avatarStorageKey: 'avatars/user.png',
      ),
    );

    final request = adapter.request;
    expect(request.method, 'PATCH');
    expect(request.path, '/api/v1/me/profile');
    expect(request.headers['Authorization'], 'Bearer current-access-token');
    expect(request.data, {
      'displayName': 'Updated',
      'bio': 'New bio',
      'phone': '+84987654321',
      'avatarStorageKey': 'avatars/user.png',
    });
    expect((request.data as Map<String, dynamic>).containsKey('userId'), isFalse);
    expect(user.displayName, 'Updated');
    expect(user.bio, 'New bio');
    expect(user.phone, '+84987654321');
  });

  test('omits null fields without converting them into clear operations', () async {
    adapter.response = _profileJson();

    await api.updateProfile(const UpdateProfileRequest(displayName: 'Updated'));

    expect(adapter.request.data, {'displayName': 'Updated'});
  });

  test('sends blank nullable fields so the backend can clear them', () async {
    adapter.response = _profileJson(bio: null, phone: null);

    await api.updateProfile(
      const UpdateProfileRequest(bio: '', phone: '', avatarStorageKey: ''),
    );

    expect(adapter.request.data, {
      'bio': '',
      'phone': '',
      'avatarStorageKey': '',
    });
  });
}

Map<String, dynamic> _profileJson({
  String? displayName,
  String? bio,
  String? phone,
}) => {
  'id': 'user-id',
  'email': 'huy@wedo.social',
  'status': 'ACTIVE',
  'emailVerified': true,
  'username': 'huy_giang',
  'displayName': displayName ?? 'Huy Giang',
  'bio': bio,
  'phone': phone,
  'avatarStorageKey': null,
};

class _RecordingAdapter implements HttpClientAdapter {
  late RequestOptions request;
  Map<String, dynamic> response = _profileJson();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode(response),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
