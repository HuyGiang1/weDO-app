/// Enum representing lifecycle statuses of a friend request.
enum FriendRequestStatus {
  pending,
  accepted,
  declined,
  cancelled;

  static FriendRequestStatus fromString(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return FriendRequestStatus.pending;
      case 'ACCEPTED':
        return FriendRequestStatus.accepted;
      case 'DECLINED':
        return FriendRequestStatus.declined;
      case 'CANCELLED':
        return FriendRequestStatus.cancelled;
      default:
        throw FormatException('Unknown FriendRequestStatus: $status');
    }
  }

  String toBackendString() {
    switch (this) {
      case FriendRequestStatus.pending:
        return 'PENDING';
      case FriendRequestStatus.accepted:
        return 'ACCEPTED';
      case FriendRequestStatus.declined:
        return 'DECLINED';
      case FriendRequestStatus.cancelled:
        return 'CANCELLED';
    }
  }
}

/// Enum representing the mutual social relationship state between two users.
enum RelationshipState {
  self,
  blocked,
  blockedBy,
  friends,
  pendingSent,
  pendingReceived,
  none;

  static RelationshipState fromString(String state) {
    switch (state.toUpperCase()) {
      case 'SELF':
        return RelationshipState.self;
      case 'BLOCKED':
        return RelationshipState.blocked;
      case 'BLOCKED_BY':
        return RelationshipState.blockedBy;
      case 'FRIENDS':
        return RelationshipState.friends;
      case 'PENDING_SENT':
        return RelationshipState.pendingSent;
      case 'PENDING_RECEIVED':
        return RelationshipState.pendingReceived;
      case 'NONE':
        return RelationshipState.none;
      default:
        throw FormatException('Unknown RelationshipState: $state');
    }
  }

  String toBackendString() {
    switch (this) {
      case RelationshipState.self:
        return 'SELF';
      case RelationshipState.blocked:
        return 'BLOCKED';
      case RelationshipState.blockedBy:
        return 'BLOCKED_BY';
      case RelationshipState.friends:
        return 'FRIENDS';
      case RelationshipState.pendingSent:
        return 'PENDING_SENT';
      case RelationshipState.pendingReceived:
        return 'PENDING_RECEIVED';
      case RelationshipState.none:
        return 'NONE';
    }
  }
}

/// Public summary of a user for social contexts.
class SocialUserSummary {
  final String id;
  final String username;
  final String displayName;
  final String? avatarStorageKey;

  const SocialUserSummary({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarStorageKey,
  });

  factory SocialUserSummary.fromJson(Map<String, dynamic> json) =>
      SocialUserSummary(
        id: _string(json, 'id'),
        username: _string(json, 'username'),
        displayName: _string(json, 'displayName'),
        avatarStorageKey: json['avatarStorageKey'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'displayName': displayName,
        if (avatarStorageKey != null) 'avatarStorageKey': avatarStorageKey,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SocialUserSummary &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          username == other.username &&
          displayName == other.displayName &&
          avatarStorageKey == other.avatarStorageKey;

  @override
  int get hashCode =>
      id.hashCode ^
      username.hashCode ^
      displayName.hashCode ^
      avatarStorageKey.hashCode;
}

/// Model representing a friend request (incoming or outgoing).
class FriendRequest {
  final String id;
  final SocialUserSummary sender;
  final SocialUserSummary receiver;
  final FriendRequestStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  const FriendRequest({
    required this.id,
    required this.sender,
    required this.receiver,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  bool get isPending => status == FriendRequestStatus.pending;
  bool get isAccepted => status == FriendRequestStatus.accepted;
  bool get isDeclined => status == FriendRequestStatus.declined;
  bool get isCancelled => status == FriendRequestStatus.cancelled;

  factory FriendRequest.fromJson(Map<String, dynamic> json) => FriendRequest(
        id: _string(json, 'id'),
        sender: SocialUserSummary.fromJson(_map(json, 'sender')),
        receiver: SocialUserSummary.fromJson(_map(json, 'receiver')),
        status: FriendRequestStatus.fromString(_string(json, 'status')),
        createdAt: _date(json, 'createdAt'),
        respondedAt: json['respondedAt'] != null
            ? _date(json, 'respondedAt')
            : null,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FriendRequest &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          sender == other.sender &&
          receiver == other.receiver &&
          status == other.status &&
          createdAt == other.createdAt &&
          respondedAt == other.respondedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      sender.hashCode ^
      receiver.hashCode ^
      status.hashCode ^
      createdAt.hashCode ^
      respondedAt.hashCode;
}

/// Model representing an active friend.
class Friend {
  final String friendshipId;
  final SocialUserSummary friend;
  final DateTime createdAt;

  const Friend({
    required this.friendshipId,
    required this.friend,
    required this.createdAt,
  });

  factory Friend.fromJson(Map<String, dynamic> json) => Friend(
        friendshipId: _string(json, 'friendshipId'),
        friend: SocialUserSummary.fromJson(_map(json, 'friend')),
        createdAt: _date(json, 'createdAt'),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Friend &&
          runtimeType == other.runtimeType &&
          friendshipId == other.friendshipId &&
          friend == other.friend &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      friendshipId.hashCode ^ friend.hashCode ^ createdAt.hashCode;
}

/// Model representing a blocked user entry.
class BlockedUser {
  final String blockId;
  final SocialUserSummary blockedUser;
  final DateTime createdAt;

  const BlockedUser({
    required this.blockId,
    required this.blockedUser,
    required this.createdAt,
  });

  factory BlockedUser.fromJson(Map<String, dynamic> json) => BlockedUser(
        blockId: _string(json, 'blockId'),
        blockedUser: SocialUserSummary.fromJson(_map(json, 'blockedUser')),
        createdAt: _date(json, 'createdAt'),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlockedUser &&
          runtimeType == other.runtimeType &&
          blockId == other.blockId &&
          blockedUser == other.blockedUser &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      blockId.hashCode ^ blockedUser.hashCode ^ createdAt.hashCode;
}

/// Model representing relationship state evaluation.
class RelationshipStatus {
  final String userId;
  final RelationshipState state;

  const RelationshipStatus({
    required this.userId,
    required this.state,
  });

  factory RelationshipStatus.fromJson(Map<String, dynamic> json) =>
      RelationshipStatus(
        userId: _string(json, 'userId'),
        state: RelationshipState.fromString(_string(json, 'state')),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RelationshipStatus &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          state == other.state;

  @override
  int get hashCode => userId.hashCode ^ state.hashCode;
}

// ---------------------------------------------------------------------------
// Helpers for safe, strict JSON decoding
// ---------------------------------------------------------------------------

String _string(Map<String, dynamic> j, String k) {
  final v = j[k];
  if (v is String && v.isNotEmpty) {
    return v;
  }
  throw FormatException('Missing or empty string for $k');
}

DateTime _date(Map<String, dynamic> j, String k) {
  final v = _string(j, k);
  final d = DateTime.tryParse(v);
  if (d == null) throw FormatException('Invalid date for $k: $v');
  return d;
}

Map<String, dynamic> _map(Map<String, dynamic> j, String k) {
  final v = j[k];
  if (v is Map) return Map<String, dynamic>.from(v);
  throw FormatException('Missing or non-map object for $k');
}
