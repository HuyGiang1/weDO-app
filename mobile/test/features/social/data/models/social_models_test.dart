import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/paged_response.dart';
import 'package:mobile/features/social/data/models/social_models.dart';

void main() {
  group('FriendRequestStatus Enum', () {
    test('parses known statuses case-insensitively', () {
      expect(
        FriendRequestStatus.fromString('PENDING'),
        FriendRequestStatus.pending,
      );
      expect(
        FriendRequestStatus.fromString('pending'),
        FriendRequestStatus.pending,
      );
      expect(
        FriendRequestStatus.fromString('ACCEPTED'),
        FriendRequestStatus.accepted,
      );
      expect(
        FriendRequestStatus.fromString('DECLINED'),
        FriendRequestStatus.declined,
      );
      expect(
        FriendRequestStatus.fromString('CANCELLED'),
        FriendRequestStatus.cancelled,
      );
    });

    test('throws FormatException on invalid status', () {
      expect(
        () => FriendRequestStatus.fromString('UNKNOWN_STATUS'),
        throwsFormatException,
      );
    });

    test('serializes to uppercase backend string', () {
      expect(FriendRequestStatus.pending.toBackendString(), 'PENDING');
      expect(FriendRequestStatus.accepted.toBackendString(), 'ACCEPTED');
      expect(FriendRequestStatus.declined.toBackendString(), 'DECLINED');
      expect(FriendRequestStatus.cancelled.toBackendString(), 'CANCELLED');
    });
  });

  group('RelationshipState Enum', () {
    test('parses all relationship states', () {
      expect(RelationshipState.fromString('SELF'), RelationshipState.self);
      expect(
        RelationshipState.fromString('BLOCKED'),
        RelationshipState.blocked,
      );
      expect(
        RelationshipState.fromString('BLOCKED_BY'),
        RelationshipState.blockedBy,
      );
      expect(
        RelationshipState.fromString('FRIENDS'),
        RelationshipState.friends,
      );
      expect(
        RelationshipState.fromString('PENDING_SENT'),
        RelationshipState.pendingSent,
      );
      expect(
        RelationshipState.fromString('PENDING_RECEIVED'),
        RelationshipState.pendingReceived,
      );
      expect(RelationshipState.fromString('NONE'), RelationshipState.none);
    });

    test('serializes to backend string representation', () {
      expect(RelationshipState.self.toBackendString(), 'SELF');
      expect(RelationshipState.blocked.toBackendString(), 'BLOCKED');
      expect(RelationshipState.blockedBy.toBackendString(), 'BLOCKED_BY');
      expect(RelationshipState.friends.toBackendString(), 'FRIENDS');
      expect(RelationshipState.pendingSent.toBackendString(), 'PENDING_SENT');
      expect(
        RelationshipState.pendingReceived.toBackendString(),
        'PENDING_RECEIVED',
      );
      expect(RelationshipState.none.toBackendString(), 'NONE');
    });
  });

  group('SocialUserSummary Model', () {
    test('parses valid JSON with avatarStorageKey', () {
      final json = {
        'id': '11111111-1111-1111-1111-111111111111',
        'username': 'alice',
        'displayName': 'Alice Wonderland',
        'avatarStorageKey': 'avatars/alice.png',
      };

      final summary = SocialUserSummary.fromJson(json);

      expect(summary.id, '11111111-1111-1111-1111-111111111111');
      expect(summary.username, 'alice');
      expect(summary.displayName, 'Alice Wonderland');
      expect(summary.avatarStorageKey, 'avatars/alice.png');
    });

    test('parses valid JSON with null avatarStorageKey', () {
      final json = {
        'id': '11111111-1111-1111-1111-111111111111',
        'username': 'bob',
        'displayName': 'Bob The Builder',
        'avatarStorageKey': null,
      };

      final summary = SocialUserSummary.fromJson(json);

      expect(summary.avatarStorageKey, isNull);
    });

    test('throws on missing required fields', () {
      expect(
        () => SocialUserSummary.fromJson({'username': 'alice'}),
        throwsFormatException,
      );
    });
  });

  group('FriendRequest Model', () {
    test('parses valid pending friend request without respondedAt', () {
      final json = {
        'id': 'req-1',
        'sender': {
          'id': 'user-1',
          'username': 'alice',
          'displayName': 'Alice',
          'avatarStorageKey': null,
        },
        'receiver': {
          'id': 'user-2',
          'username': 'bob',
          'displayName': 'Bob',
          'avatarStorageKey': 'avatar.jpg',
        },
        'status': 'PENDING',
        'createdAt': '2026-09-13T10:00:00Z',
        'respondedAt': null,
      };

      final request = FriendRequest.fromJson(json);

      expect(request.id, 'req-1');
      expect(request.sender.username, 'alice');
      expect(request.receiver.displayName, 'Bob');
      expect(request.status, FriendRequestStatus.pending);
      expect(request.isPending, isTrue);
      expect(request.isAccepted, isFalse);
      expect(request.createdAt, DateTime.parse('2026-09-13T10:00:00Z'));
      expect(request.respondedAt, isNull);
    });

    test('parses accepted friend request with respondedAt', () {
      final json = {
        'id': 'req-2',
        'sender': {
          'id': 'user-1',
          'username': 'alice',
          'displayName': 'Alice',
        },
        'receiver': {
          'id': 'user-2',
          'username': 'bob',
          'displayName': 'Bob',
        },
        'status': 'ACCEPTED',
        'createdAt': '2026-09-13T10:00:00Z',
        'respondedAt': '2026-09-13T10:05:00Z',
      };

      final request = FriendRequest.fromJson(json);

      expect(request.status, FriendRequestStatus.accepted);
      expect(request.isAccepted, isTrue);
      expect(request.respondedAt, isNotNull);
    });
  });

  group('Friend Model', () {
    test('parses valid friend JSON', () {
      final json = {
        'friendshipId': 'f-100',
        'friend': {
          'id': 'user-2',
          'username': 'bob',
          'displayName': 'Bob',
          'avatarStorageKey': null,
        },
        'createdAt': '2026-09-13T09:30:00Z',
      };

      final friend = Friend.fromJson(json);

      expect(friend.friendshipId, 'f-100');
      expect(friend.friend.username, 'bob');
      expect(friend.createdAt, DateTime.parse('2026-09-13T09:30:00Z'));
    });
  });

  group('BlockedUser Model', () {
    test('parses valid blocked user JSON', () {
      final json = {
        'blockId': 'b-200',
        'blockedUser': {
          'id': 'user-3',
          'username': 'charlie',
          'displayName': 'Charlie',
          'avatarStorageKey': null,
        },
        'createdAt': '2026-09-13T08:00:00Z',
      };

      final blocked = BlockedUser.fromJson(json);

      expect(blocked.blockId, 'b-200');
      expect(blocked.blockedUser.username, 'charlie');
      expect(blocked.createdAt, DateTime.parse('2026-09-13T08:00:00Z'));
    });
  });

  group('RelationshipStatus Model', () {
    test('parses valid relationship status JSON', () {
      final json = {
        'userId': 'user-99',
        'state': 'FRIENDS',
      };

      final status = RelationshipStatus.fromJson(json);

      expect(status.userId, 'user-99');
      expect(status.state, RelationshipState.friends);
    });
  });

  group('PagedResponse Model', () {
    test('parses generic paginated list properly', () {
      final json = {
        'items': [
          {
            'id': 'u1',
            'username': 'user1',
            'displayName': 'User One',
          },
          {
            'id': 'u2',
            'username': 'user2',
            'displayName': 'User Two',
          },
        ],
        'page': 0,
        'size': 20,
        'totalElements': 2,
        'totalPages': 1,
        'hasNext': false,
      };

      final paged = PagedResponse.fromJson(json, SocialUserSummary.fromJson);

      expect(paged.items.length, 2);
      expect(paged.items.first.username, 'user1');
      expect(paged.page, 0);
      expect(paged.size, 20);
      expect(paged.totalElements, 2);
      expect(paged.totalPages, 1);
      expect(paged.hasNext, isFalse);
      expect(paged.isEmpty, isFalse);
      expect(paged.isFirstPage, isTrue);
      expect(paged.isLastPage, isTrue);
    });

    test('handles empty page properly', () {
      final json = {
        'items': <dynamic>[],
        'page': 0,
        'size': 30,
        'totalElements': 0,
        'totalPages': 0,
        'hasNext': false,
      };

      final paged = PagedResponse.fromJson(json, SocialUserSummary.fromJson);

      expect(paged.items, isEmpty);
      expect(paged.isEmpty, isTrue);
      expect(paged.hasNext, isFalse);
    });
  });
}
