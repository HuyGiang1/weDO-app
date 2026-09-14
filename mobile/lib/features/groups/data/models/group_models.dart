enum GroupStatus {
  active('ACTIVE'),
  archived('ARCHIVED'),
  deleted('DELETED');

  final String wireValue;
  const GroupStatus(this.wireValue);
  static GroupStatus fromWire(String v) => GroupStatus.values.firstWhere(
    (e) => e.wireValue == v,
    orElse: () => throw FormatException('Unknown GroupStatus: $v'),
  );
}

enum GroupRole {
  owner('OWNER'),
  admin('ADMIN'),
  member('MEMBER');

  final String wireValue;
  const GroupRole(this.wireValue);
  static GroupRole fromWire(String v) => GroupRole.values.firstWhere(
    (e) => e.wireValue == v,
    orElse: () => throw FormatException('Unknown GroupRole: $v'),
  );
}

enum GroupJoinPolicy {
  autoJoin('AUTO_JOIN'),
  approvalRequired('APPROVAL_REQUIRED');

  final String wireValue;
  const GroupJoinPolicy(this.wireValue);
  static GroupJoinPolicy fromWire(String v) =>
      GroupJoinPolicy.values.firstWhere(
        (e) => e.wireValue == v,
        orElse: () => throw FormatException('Unknown GroupJoinPolicy: $v'),
      );
}

enum ChatHistoryPolicy {
  fullHistory('FULL_HISTORY'),
  fromJoinTime('FROM_JOIN_TIME');

  final String wireValue;
  const ChatHistoryPolicy(this.wireValue);
  static ChatHistoryPolicy fromWire(String v) =>
      ChatHistoryPolicy.values.firstWhere(
        (e) => e.wireValue == v,
        orElse: () => throw FormatException('Unknown ChatHistoryPolicy: $v'),
      );
}

String _s(Map<String, dynamic> j, String k) {
  final v = j[k];
  if (v is! String) throw FormatException('Expected string $k');
  return v;
}

DateTime _d(Map<String, dynamic> j, String k) => DateTime.parse(_s(j, k));

class GroupSummary {
  final String id, name;
  final String? avatarStorageKey;
  final GroupStatus status;
  final GroupRole callerRole;
  final DateTime updatedAt;
  const GroupSummary({
    required this.id,
    required this.name,
    this.avatarStorageKey,
    required this.status,
    required this.callerRole,
    required this.updatedAt,
  });
  factory GroupSummary.fromJson(Map<String, dynamic> j) => GroupSummary(
    id: _s(j, 'id'),
    name: _s(j, 'name'),
    avatarStorageKey: j['avatarStorageKey'] as String?,
    status: GroupStatus.fromWire(_s(j, 'status')),
    callerRole: GroupRole.fromWire(_s(j, 'callerRole')),
    updatedAt: _d(j, 'updatedAt'),
  );
}

class GroupDetail {
  final String id, name, ownerUserId;
  final String? description, avatarStorageKey;
  final GroupStatus status;
  final GroupRole callerRole;
  final DateTime createdAt, updatedAt;
  const GroupDetail({
    required this.id,
    required this.name,
    this.description,
    this.avatarStorageKey,
    required this.status,
    required this.ownerUserId,
    required this.callerRole,
    required this.createdAt,
    required this.updatedAt,
  });
  factory GroupDetail.fromJson(Map<String, dynamic> j) => GroupDetail(
    id: _s(j, 'id'),
    name: _s(j, 'name'),
    description: j['description'] as String?,
    avatarStorageKey: j['avatarStorageKey'] as String?,
    status: GroupStatus.fromWire(_s(j, 'status')),
    ownerUserId: _s(j, 'ownerUserId'),
    callerRole: GroupRole.fromWire(_s(j, 'callerRole')),
    createdAt: _d(j, 'createdAt'),
    updatedAt: _d(j, 'updatedAt'),
  );
}

class CreatedGroup {
  final String id, name, createdBy;
  final String? description, avatarStorageKey;
  final GroupStatus status;
  final DateTime createdAt, updatedAt;
  const CreatedGroup({
    required this.id,
    required this.name,
    this.description,
    this.avatarStorageKey,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });
  factory CreatedGroup.fromJson(Map<String, dynamic> j) => CreatedGroup(
    id: _s(j, 'id'),
    name: _s(j, 'name'),
    description: j['description'] as String?,
    avatarStorageKey: j['avatarStorageKey'] as String?,
    status: GroupStatus.fromWire(_s(j, 'status')),
    createdBy: _s(j, 'createdBy'),
    createdAt: _d(j, 'createdAt'),
    updatedAt: _d(j, 'updatedAt'),
  );
}

class GroupMember {
  final String userId, username, displayName;
  final String? avatarStorageKey;
  final GroupRole role;
  final DateTime joinedAt;
  const GroupMember({
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatarStorageKey,
    required this.role,
    required this.joinedAt,
  });
  factory GroupMember.fromJson(Map<String, dynamic> j) => GroupMember(
    userId: _s(j, 'userId'),
    username: _s(j, 'username'),
    displayName: _s(j, 'displayName'),
    avatarStorageKey: j['avatarStorageKey'] as String?,
    role: GroupRole.fromWire(_s(j, 'role')),
    joinedAt: _d(j, 'joinedAt'),
  );
}

class GroupSettings {
  final String groupId;
  final GroupJoinPolicy joinPolicy;
  final bool memberModifyInfoAllowed,
      memberCreateActivityAllowed,
      memberPinMessageAllowed;
  final ChatHistoryPolicy chatHistoryPolicy;
  final DateTime updatedAt;
  const GroupSettings({
    required this.groupId,
    required this.joinPolicy,
    required this.memberModifyInfoAllowed,
    required this.memberCreateActivityAllowed,
    required this.memberPinMessageAllowed,
    required this.chatHistoryPolicy,
    required this.updatedAt,
  });
  factory GroupSettings.fromJson(Map<String, dynamic> j) => GroupSettings(
    groupId: _s(j, 'groupId'),
    joinPolicy: GroupJoinPolicy.fromWire(_s(j, 'joinPolicy')),
    memberModifyInfoAllowed: j['memberModifyInfoAllowed'] as bool,
    memberCreateActivityAllowed: j['memberCreateActivityAllowed'] as bool,
    memberPinMessageAllowed: j['memberPinMessageAllowed'] as bool,
    chatHistoryPolicy: ChatHistoryPolicy.fromWire(_s(j, 'chatHistoryPolicy')),
    updatedAt: _d(j, 'updatedAt'),
  );
}

class CreateGroupRequest {
  final String name;
  final String? description, avatarStorageKey;
  const CreateGroupRequest({
    required this.name,
    this.description,
    this.avatarStorageKey,
  });
  Map<String, dynamic> toJson() => {
    'name': name,
    if (description != null) 'description': description,
    if (avatarStorageKey != null) 'avatarStorageKey': avatarStorageKey,
  };
}

class UpdateGroupRequest {
  final String? name, description, avatarStorageKey;
  const UpdateGroupRequest({
    this.name,
    this.description,
    this.avatarStorageKey,
  });
  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name,
    if (description != null) 'description': description,
    if (avatarStorageKey != null) 'avatarStorageKey': avatarStorageKey,
  };
}

class UpdateGroupSettingsRequest {
  final GroupJoinPolicy? joinPolicy;
  final bool? memberModifyInfoAllowed,
      memberCreateActivityAllowed,
      memberPinMessageAllowed;
  final ChatHistoryPolicy? chatHistoryPolicy;
  const UpdateGroupSettingsRequest({
    this.joinPolicy,
    this.memberModifyInfoAllowed,
    this.memberCreateActivityAllowed,
    this.memberPinMessageAllowed,
    this.chatHistoryPolicy,
  });
  Map<String, dynamic> toJson() => {
    if (joinPolicy != null) 'joinPolicy': joinPolicy!.wireValue,
    if (memberModifyInfoAllowed != null)
      'memberModifyInfoAllowed': memberModifyInfoAllowed,
    if (memberCreateActivityAllowed != null)
      'memberCreateActivityAllowed': memberCreateActivityAllowed,
    if (memberPinMessageAllowed != null)
      'memberPinMessageAllowed': memberPinMessageAllowed,
    if (chatHistoryPolicy != null)
      'chatHistoryPolicy': chatHistoryPolicy!.wireValue,
  };
}

class TransferOwnershipRequest {
  final String newOwnerUserId;
  const TransferOwnershipRequest(this.newOwnerUserId);
  Map<String, dynamic> toJson() => {'newOwnerUserId': newOwnerUserId};
}
