import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/privacy/data/privacy_api.dart';
import 'package:mobile/features/privacy/data/privacy_models.dart';
import 'package:mobile/features/privacy/data/privacy_repository.dart';

void main() {
  test('delegates GET and PATCH without changing the privacy payload', () async {
    final api = _FakePrivacyApi();
    final repository = PrivacyRepository(api: api);
    const request = UpdatePrivacySettingsRequest(discoverByPhone: false);

    expect(await repository.getPrivacySettings(), same(api.settings));
    expect(await repository.updatePrivacySettings(request), same(api.settings));
    expect(api.receivedRequest, same(request));
  });
}

class _FakePrivacyApi extends PrivacyApi {
  _FakePrivacyApi() : super(Dio());

  final settings = const PrivacySettings(
    discoverByUsername: true,
    discoverByQr: true,
    discoverByEmail: false,
    discoverByPhone: false,
    dmPolicy: DmPolicy.everyone,
    friendRequestPolicy: FriendRequestPolicy.everyone,
    showOnlineStatus: true,
    showLastSeen: true,
  );
  UpdatePrivacySettingsRequest? receivedRequest;

  @override
  Future<PrivacySettings> getPrivacySettings() async => settings;

  @override
  Future<PrivacySettings> updatePrivacySettings(
    UpdatePrivacySettingsRequest request,
  ) async {
    receivedRequest = request;
    return settings;
  }
}
