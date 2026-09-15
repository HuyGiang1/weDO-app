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
DateTime? _nd(Map<String, dynamic> j, String k) =>
    j[k] != null ? DateTime.parse(_s(j, k)) : null;
int? _ni(Map<String, dynamic> j, String k) =>
    j[k] != null ? (j[k] as num).toInt() : null;

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

/// History is intentionally tolerant of future backend action values.
/// Presentation maps unknown values to a safe generic activity card.
class GroupActivityLog {
  final String id, action;
  final String? actorUserId, targetUserId;
  final DateTime createdAt;
  const GroupActivityLog({
    required this.id,
    required this.action,
    this.actorUserId,
    this.targetUserId,
    required this.createdAt,
  });
  factory GroupActivityLog.fromJson(Map<String, dynamic> j) => GroupActivityLog(
    id: _s(j, 'id'),
    action: _s(j, 'action'),
    actorUserId: j['actorUserId'] as String?,
    targetUserId: j['targetUserId'] as String?,
    createdAt: _d(j, 'createdAt'),
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

enum GroupInvitationStatus {
  pending('PENDING'),
  accepted('ACCEPTED'),
  declined('DECLINED'),
  cancelled('CANCELLED');

  final String wireValue;
  const GroupInvitationStatus(this.wireValue);
  static GroupInvitationStatus fromWire(String v) =>
      GroupInvitationStatus.values.firstWhere(
        (e) => e.wireValue == v,
        orElse: () => throw FormatException('Unknown GroupInvitationStatus: $v'),
      );
}

class GroupInvitationResponse {
  final String id, groupId, inviterUserId, inviteeUserId;
  final GroupInvitationStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  const GroupInvitationResponse({
    required this.id,
    required this.groupId,
    required this.inviterUserId,
    required this.inviteeUserId,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  factory GroupInvitationResponse.fromJson(Map<String, dynamic> j) =>
      GroupInvitationResponse(
        id: _s(j, 'id'),
        groupId: _s(j, 'groupId'),
        inviterUserId: (j['inviterId'] ?? j['inviterUserId']) as String,
        inviteeUserId: (j['inviteeId'] ?? j['inviteeUserId']) as String,
        status: GroupInvitationStatus.fromWire(_s(j, 'status')),
        createdAt: _d(j, 'createdAt'),
        respondedAt: _nd(j, 'respondedAt'),
      );
}

class CreateInvitationRequest {
  final String inviteeUserId;
  const CreateInvitationRequest({required this.inviteeUserId});
  Map<String, dynamic> toJson() => {'inviteeUserId': inviteeUserId};
}

class InviteLinkResponse {
  final String id, groupId, inviteCode, creatorUserId;
  final DateTime? expiresAt;
  final int? maxUses;
  final int usesCount;
  final bool isRevoked;
  final DateTime createdAt;

  const InviteLinkResponse({
    required this.id,
    required this.groupId,
    required this.inviteCode,
    required this.creatorUserId,
    this.expiresAt,
    this.maxUses,
    required this.usesCount,
    required this.isRevoked,
    required this.createdAt,
  });

  factory InviteLinkResponse.fromJson(Map<String, dynamic> j) =>
      InviteLinkResponse(
        id: _s(j, 'id'),
        groupId: _s(j, 'groupId'),
        inviteCode: (j['code'] ?? j['inviteCode']) as String,
        creatorUserId: (j['createdBy'] ?? j['creatorUserId']) as String,
        expiresAt: _nd(j, 'expiresAt'),
        maxUses: _ni(j, 'maxUses'),
        usesCount: (j['usesCount'] as num).toInt(),
        isRevoked: j['isRevoked'] as bool? ?? (j['revoked'] as bool? ?? false),
        createdAt: _d(j, 'createdAt'),
      );
}

class CreateInviteLinkRequest {
  final DateTime? expiresAt;
  final int? maxUses;

  const CreateInviteLinkRequest({this.expiresAt, this.maxUses});

  Map<String, dynamic> toJson() => {
    if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
    if (maxUses != null) 'maxUses': maxUses,
  };
}

class GroupInviteSummaryResponse {
  final String groupId, groupName;
  final String? groupAvatarStorageKey, groupDescription;
  final GroupJoinPolicy joinPolicy;
  final int activeMemberCount;

  const GroupInviteSummaryResponse({
    required this.groupId,
    required this.groupName,
    this.groupAvatarStorageKey,
    this.groupDescription,
    required this.joinPolicy,
    required this.activeMemberCount,
  });

  factory GroupInviteSummaryResponse.fromJson(Map<String, dynamic> j) =>
      GroupInviteSummaryResponse(
        groupId: _s(j, 'groupId'),
        groupName: (j['name'] ?? j['groupName']) as String,
        groupAvatarStorageKey: (j['avatarStorageKey'] ?? j['groupAvatarStorageKey']) as String?,
        groupDescription: (j['description'] ?? j['groupDescription']) as String?,
        joinPolicy: GroupJoinPolicy.fromWire(_s(j, 'joinPolicy')),
        activeMemberCount: ((j['memberCount'] ?? j['activeMemberCount']) as num).toInt(),
      );
}

enum GroupJoinRequestStatus {
  pending('PENDING'),
  approved('APPROVED'),
  rejected('REJECTED'),
  cancelled('CANCELLED');

  final String wireValue;
  const GroupJoinRequestStatus(this.wireValue);
  static GroupJoinRequestStatus fromWire(String v) =>
      GroupJoinRequestStatus.values.firstWhere(
        (e) => e.wireValue == v,
        orElse: () => throw FormatException('Unknown GroupJoinRequestStatus: $v'),
      );
}

class JoinRequestResponse {
  final String id, groupId, requesterUserId;
  final GroupJoinRequestStatus status;
  final String? reviewedByUserId;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  const JoinRequestResponse({
    required this.id,
    required this.groupId,
    required this.requesterUserId,
    required this.status,
    this.reviewedByUserId,
    required this.createdAt,
    this.reviewedAt,
  });

  factory JoinRequestResponse.fromJson(Map<String, dynamic> j) =>
      JoinRequestResponse(
        id: _s(j, 'id'),
        groupId: _s(j, 'groupId'),
        requesterUserId: (j['userId'] ?? j['requesterUserId']) as String,
        status: GroupJoinRequestStatus.fromWire(_s(j, 'status')),
        reviewedByUserId: (j['respondedBy'] ?? j['reviewedByUserId']) as String?,
        createdAt: _d(j, 'createdAt'),
        reviewedAt: _nd(j, 'respondedAt') ?? _nd(j, 'reviewedAt'),
      );
}

class BanMemberRequest {
  final String? reason;
  const BanMemberRequest({this.reason});
  Map<String, dynamic> toJson() => {if (reason != null) 'reason': reason};
}

class GroupBanResponse {
  final String id, groupId, bannedUserId, bannedByUserId;
  final String? reason;
  final DateTime createdAt;

  const GroupBanResponse({
    required this.id,
    required this.groupId,
    required this.bannedUserId,
    required this.bannedByUserId,
    this.reason,
    required this.createdAt,
  });

  factory GroupBanResponse.fromJson(Map<String, dynamic> j) => GroupBanResponse(
    id: _s(j, 'id'),
    groupId: _s(j, 'groupId'),
    bannedUserId: (j['userId'] ?? j['bannedUserId']) as String,
    bannedByUserId: (j['bannedBy'] ?? j['bannedByUserId']) as String,
    reason: j['reason'] as String?,
    createdAt: _d(j, 'createdAt'),
  );
}

