import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/privacy/data/privacy_models.dart';

void main() {
  const settings = PrivacySettings(
    discoverByUsername: true,
    discoverByQr: true,
    discoverByEmail: false,
    discoverByPhone: false,
    dmPolicy: DmPolicy.everyone,
    friendRequestPolicy: FriendRequestPolicy.everyone,
    showOnlineStatus: true,
    showLastSeen: true,
  );

  test('parses exact privacy wire values and rejects unknown enums', () {
    final parsed = PrivacySettings.fromJson({
      'discoverByUsername': true,
      'discoverByQr': true,
      'discoverByEmail': false,
      'discoverByPhone': false,
      'dmPolicy': 'MUTUAL_GROUPS',
      'friendRequestPolicy': 'NONE',
      'showOnlineStatus': true,
      'showLastSeen': false,
    });
    expect(parsed.dmPolicy, DmPolicy.mutualGroups);
    expect(parsed.friendRequestPolicy, FriendRequestPolicy.none);
    expect(
      () => PrivacySettings.fromJson({
        'discoverByUsername': true,
        'discoverByQr': true,
        'discoverByEmail': false,
        'discoverByPhone': false,
        'dmPolicy': 'UNKNOWN',
        'friendRequestPolicy': 'NONE',
        'showOnlineStatus': true,
        'showLastSeen': false,
      }),
      throwsFormatException,
    );
  });

  test('PATCH omits null fields and retains explicit false', () {
    expect(
      const UpdatePrivacySettingsRequest(discoverByPhone: false).toJson(),
      {'discoverByPhone': false},
    );
    expect(const UpdatePrivacySettingsRequest().toJson(), isEmpty);
    expect(
      settings.copyWith(discoverByPhone: true).changesFrom(settings).toJson(),
      {'discoverByPhone': true},
    );
  });
}
