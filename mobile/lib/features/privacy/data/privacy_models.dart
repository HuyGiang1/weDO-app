enum DmPolicy {
  everyone('EVERYONE'),
  mutualGroups('MUTUAL_GROUPS'),
  friendsOnly('FRIENDS_ONLY');

  final String wireValue;
  const DmPolicy(this.wireValue);

  static DmPolicy fromWireValue(String value) => DmPolicy.values.firstWhere(
    (policy) => policy.wireValue == value,
    orElse: () => throw FormatException('Unknown DmPolicy: $value'),
  );
}

enum FriendRequestPolicy {
  everyone('EVERYONE'),
  mutualGroups('MUTUAL_GROUPS'),
  none('NONE');

  final String wireValue;
  const FriendRequestPolicy(this.wireValue);

  static FriendRequestPolicy fromWireValue(String value) =>
      FriendRequestPolicy.values.firstWhere(
        (policy) => policy.wireValue == value,
        orElse: () =>
            throw FormatException('Unknown FriendRequestPolicy: $value'),
      );
}

class PrivacySettings {
  final bool discoverByUsername;
  final bool discoverByQr;
  final bool discoverByEmail;
  final bool discoverByPhone;
  final DmPolicy dmPolicy;
  final FriendRequestPolicy friendRequestPolicy;
  final bool showOnlineStatus;
  final bool showLastSeen;

  const PrivacySettings({
    required this.discoverByUsername,
    required this.discoverByQr,
    required this.discoverByEmail,
    required this.discoverByPhone,
    required this.dmPolicy,
    required this.friendRequestPolicy,
    required this.showOnlineStatus,
    required this.showLastSeen,
  });

  factory PrivacySettings.fromJson(Map<String, dynamic> json) =>
      PrivacySettings(
        discoverByUsername: _boolean(json, 'discoverByUsername'),
        discoverByQr: _boolean(json, 'discoverByQr'),
        discoverByEmail: _boolean(json, 'discoverByEmail'),
        discoverByPhone: _boolean(json, 'discoverByPhone'),
        dmPolicy: DmPolicy.fromWireValue(_string(json, 'dmPolicy')),
        friendRequestPolicy: FriendRequestPolicy.fromWireValue(
          _string(json, 'friendRequestPolicy'),
        ),
        showOnlineStatus: _boolean(json, 'showOnlineStatus'),
        showLastSeen: _boolean(json, 'showLastSeen'),
      );

  PrivacySettings copyWith({
    bool? discoverByUsername,
    bool? discoverByQr,
    bool? discoverByEmail,
    bool? discoverByPhone,
    DmPolicy? dmPolicy,
    FriendRequestPolicy? friendRequestPolicy,
    bool? showOnlineStatus,
    bool? showLastSeen,
  }) => PrivacySettings(
    discoverByUsername: discoverByUsername ?? this.discoverByUsername,
    discoverByQr: discoverByQr ?? this.discoverByQr,
    discoverByEmail: discoverByEmail ?? this.discoverByEmail,
    discoverByPhone: discoverByPhone ?? this.discoverByPhone,
    dmPolicy: dmPolicy ?? this.dmPolicy,
    friendRequestPolicy: friendRequestPolicy ?? this.friendRequestPolicy,
    showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
    showLastSeen: showLastSeen ?? this.showLastSeen,
  );

  UpdatePrivacySettingsRequest changesFrom(
    PrivacySettings baseline,
  ) => UpdatePrivacySettingsRequest(
    discoverByUsername: discoverByUsername == baseline.discoverByUsername
        ? null
        : discoverByUsername,
    discoverByQr: discoverByQr == baseline.discoverByQr ? null : discoverByQr,
    discoverByEmail: discoverByEmail == baseline.discoverByEmail
        ? null
        : discoverByEmail,
    discoverByPhone: discoverByPhone == baseline.discoverByPhone
        ? null
        : discoverByPhone,
    dmPolicy: dmPolicy == baseline.dmPolicy ? null : dmPolicy,
    friendRequestPolicy: friendRequestPolicy == baseline.friendRequestPolicy
        ? null
        : friendRequestPolicy,
    showOnlineStatus: showOnlineStatus == baseline.showOnlineStatus
        ? null
        : showOnlineStatus,
    showLastSeen: showLastSeen == baseline.showLastSeen ? null : showLastSeen,
  );
}

class UpdatePrivacySettingsRequest {
  final bool? discoverByUsername;
  final bool? discoverByQr;
  final bool? discoverByEmail;
  final bool? discoverByPhone;
  final DmPolicy? dmPolicy;
  final FriendRequestPolicy? friendRequestPolicy;
  final bool? showOnlineStatus;
  final bool? showLastSeen;

  const UpdatePrivacySettingsRequest({
    this.discoverByUsername,
    this.discoverByQr,
    this.discoverByEmail,
    this.discoverByPhone,
    this.dmPolicy,
    this.friendRequestPolicy,
    this.showOnlineStatus,
    this.showLastSeen,
  });

  bool get isEmpty => toJson().isEmpty;

  Map<String, dynamic> toJson() => {
    if (discoverByUsername != null) 'discoverByUsername': discoverByUsername,
    if (discoverByQr != null) 'discoverByQr': discoverByQr,
    if (discoverByEmail != null) 'discoverByEmail': discoverByEmail,
    if (discoverByPhone != null) 'discoverByPhone': discoverByPhone,
    if (dmPolicy != null) 'dmPolicy': dmPolicy!.wireValue,
    if (friendRequestPolicy != null)
      'friendRequestPolicy': friendRequestPolicy!.wireValue,
    if (showOnlineStatus != null) 'showOnlineStatus': showOnlineStatus,
    if (showLastSeen != null) 'showLastSeen': showLastSeen,
  };
}

bool _boolean(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('Expected boolean $key');
  return value;
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('Expected string $key');
  return value;
}
