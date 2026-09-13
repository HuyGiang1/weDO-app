import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/paged_response.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/social/data/models/social_models.dart';
import 'package:mobile/features/social/data/social_api.dart';
import 'package:mobile/features/social/data/social_failure.dart';
import 'package:mobile/features/social/data/social_repository.dart';

class FakeSocialApi extends SocialApi {
  FakeSocialApi() : super(Dio());

  FriendRequest? fakeRequest;
  PagedResponse<FriendRequest>? fakeReceivedPage;
  PagedResponse<FriendRequest>? fakeSentPage;
  PagedResponse<Friend>? fakeFriendsPage;
  PagedResponse<BlockedUser>? fakeBlockedPage;
  RelationshipStatus? fakeRelationship;

  ApiException? errorToThrow;

  @override
  Future<FriendRequest> sendFriendRequest(String userId) async {
    if (errorToThrow != null) throw errorToThrow!;
    return fakeRequest!;
  }

  @override
  Future<PagedResponse<FriendRequest>> getReceivedFriendRequests({
    int page = 0,
    int size = 30,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    return fakeReceivedPage!;
  }

  @override
  Future<PagedResponse<FriendRequest>> getSentFriendRequests({
    int page = 0,
    int size = 30,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    return fakeSentPage!;
  }

  @override
  Future<FriendRequest> acceptFriendRequest(String requestId) async {
    if (errorToThrow != null) throw errorToThrow!;
    return fakeRequest!;
  }

  @override
  Future<void> declineFriendRequest(String requestId) async {
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<void> cancelFriendRequest(String requestId) async {
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<PagedResponse<Friend>> getFriends({
    int page = 0,
    int size = 30,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    return fakeFriendsPage!;
  }

  @override
  Future<void> unfriend(String userId) async {
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<void> blockUser(String userId) async {
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<void> unblockUser(String userId) async {
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<PagedResponse<BlockedUser>> getBlockedUsers({
    int page = 0,
    int size = 30,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    return fakeBlockedPage!;
  }

  @override
  Future<RelationshipStatus> getRelationship(String userId) async {
    if (errorToThrow != null) throw errorToThrow!;
    return fakeRelationship!;
  }
}

void main() {
  late FakeSocialApi fakeApi;
  late SocialRepository repository;

  final sampleUser1 = const SocialUserSummary(
    id: 'user-1',
    username: 'alice',
    displayName: 'Alice',
  );
  final sampleUser2 = const SocialUserSummary(
    id: 'user-2',
    username: 'bob',
    displayName: 'Bob',
  );

  final sampleRequest = FriendRequest(
    id: 'req-1',
    sender: sampleUser1,
    receiver: sampleUser2,
    status: FriendRequestStatus.pending,
    createdAt: DateTime.parse('2026-09-13T10:00:00Z'),
  );

  setUp(() {
    fakeApi = FakeSocialApi();
    repository = SocialRepository(api: fakeApi);
  });

  group('SocialRepository Friend Requests', () {
    test('sendFriendRequest succeeds', () async {
      fakeApi.fakeRequest = sampleRequest;

      final result = await repository.sendFriendRequest('user-2');

      expect(result.id, 'req-1');
      expect(result.status, FriendRequestStatus.pending);
    });

    test('sendFriendRequest translates CANNOT_FRIEND_SELF to typed SocialException', () async {
      fakeApi.errorToThrow = const ApiException(
        statusCode: 400,
        code: 'CANNOT_FRIEND_SELF',
        message: 'Cannot send friend request to yourself.',
      );

      try {
        await repository.sendFriendRequest('user-1');
        fail('Expected SocialException');
      } on SocialException catch (e) {
        expect(e.failure.type, SocialFailureType.cannotFriendSelf);
        expect(e.failure.backendCode, 'CANNOT_FRIEND_SELF');
      }
    });

    test('sendFriendRequest translates duplicate pending to typed SocialException', () async {
      fakeApi.errorToThrow = const ApiException(
        statusCode: 409,
        code: 'FRIEND_REQUEST_ALREADY_PENDING',
        message: 'A friend request is already pending.',
      );

      try {
        await repository.sendFriendRequest('user-2');
        fail('Expected SocialException');
      } on SocialException catch (e) {
        expect(e.failure.type, SocialFailureType.friendRequestAlreadyPending);
      }
    });

    test('sendFriendRequest translates 24h cooldown to typed SocialException', () async {
      fakeApi.errorToThrow = const ApiException(
        statusCode: 429,
        code: 'FRIEND_REQUEST_COOLDOWN_ACTIVE',
        message: 'Please wait before sending another friend request.',
      );

      try {
        await repository.sendFriendRequest('user-2');
        fail('Expected SocialException');
      } on SocialException catch (e) {
        expect(e.failure.type, SocialFailureType.friendRequestCooldownActive);
      }
    });

    test('getReceivedFriendRequests returns paged list', () async {
      fakeApi.fakeReceivedPage = PagedResponse(
        items: [sampleRequest],
        page: 0,
        size: 30,
        totalElements: 1,
        totalPages: 1,
        hasNext: false,
      );

      final result = await repository.getReceivedFriendRequests();

      expect(result.items.length, 1);
      expect(result.items.first.id, 'req-1');
      expect(result.hasNext, isFalse);
    });

    test('getSentFriendRequests returns paged list', () async {
      fakeApi.fakeSentPage = const PagedResponse(
        items: [],
        page: 0,
        size: 30,
        totalElements: 0,
        totalPages: 0,
        hasNext: false,
      );

      final result = await repository.getSentFriendRequests();

      expect(result.items, isEmpty);
      expect(result.isEmpty, isTrue);
    });

    test('acceptFriendRequest succeeds', () async {
      final accepted = FriendRequest(
        id: 'req-1',
        sender: sampleUser1,
        receiver: sampleUser2,
        status: FriendRequestStatus.accepted,
        createdAt: DateTime.parse('2026-09-13T10:00:00Z'),
        respondedAt: DateTime.parse('2026-09-13T10:01:00Z'),
      );
      fakeApi.fakeRequest = accepted;

      final result = await repository.acceptFriendRequest('req-1');

      expect(result.isAccepted, isTrue);
    });

    test('acceptFriendRequest translates ACCESS_DENIED on non-receiver attempt', () async {
      fakeApi.errorToThrow = const ApiException(
        statusCode: 403,
        code: 'ACCESS_DENIED',
        message: 'Access denied.',
      );

      try {
        await repository.acceptFriendRequest('req-1');
        fail('Expected SocialException');
      } on SocialException catch (e) {
        expect(e.failure.type, SocialFailureType.accessDenied);
      }
    });

    test('declineFriendRequest succeeds', () async {
      await expectLater(repository.declineFriendRequest('req-1'), completes);
    });

    test('cancelFriendRequest succeeds', () async {
      await expectLater(repository.cancelFriendRequest('req-1'), completes);
    });
  });

  group('SocialRepository Friendship', () {
    test('getFriends returns paginated friends', () async {
      fakeApi.fakeFriendsPage = PagedResponse(
        items: [
          Friend(
            friendshipId: 'fs-1',
            friend: sampleUser2,
            createdAt: DateTime.parse('2026-09-13T10:00:00Z'),
          ),
        ],
        page: 0,
        size: 30,
        totalElements: 1,
        totalPages: 1,
        hasNext: false,
      );

      final result = await repository.getFriends();

      expect(result.items.length, 1);
      expect(result.items.first.friend.username, 'bob');
    });

    test('unfriend succeeds', () async {
      await expectLater(repository.unfriend('user-2'), completes);
    });

    test('unfriend translates FRIENDSHIP_NOT_FOUND', () async {
      fakeApi.errorToThrow = const ApiException(
        statusCode: 404,
        code: 'FRIENDSHIP_NOT_FOUND',
        message: 'Friendship was not found.',
      );

      try {
        await repository.unfriend('not-a-friend');
        fail('Expected SocialException');
      } on SocialException catch (e) {
        expect(e.failure.type, SocialFailureType.friendshipNotFound);
      }
    });
  });

  group('SocialRepository Block', () {
    test('blockUser succeeds', () async {
      await expectLater(repository.blockUser('bad-user'), completes);
    });

    test('blockUser translates CANNOT_BLOCK_SELF', () async {
      fakeApi.errorToThrow = const ApiException(
        statusCode: 400,
        code: 'CANNOT_BLOCK_SELF',
        message: 'Cannot block yourself.',
      );

      try {
        await repository.blockUser('self');
        fail('Expected SocialException');
      } on SocialException catch (e) {
        expect(e.failure.type, SocialFailureType.cannotBlockSelf);
      }
    });

    test('unblockUser succeeds', () async {
      await expectLater(repository.unblockUser('bad-user'), completes);
    });

    test('getBlockedUsers returns paginated blocked list', () async {
      fakeApi.fakeBlockedPage = PagedResponse(
        items: [
          BlockedUser(
            blockId: 'b-1',
            blockedUser: sampleUser2,
            createdAt: DateTime.parse('2026-09-13T10:00:00Z'),
          ),
        ],
        page: 0,
        size: 30,
        totalElements: 1,
        totalPages: 1,
        hasNext: false,
      );

      final result = await repository.getBlockedUsers();

      expect(result.items.length, 1);
      expect(result.items.first.blockedUser.username, 'bob');
    });
  });

  group('SocialRepository Relationship (Deviation / Optional)', () {
    test('getRelationship returns relationship state', () async {
      fakeApi.fakeRelationship = const RelationshipStatus(
        userId: 'user-2',
        state: RelationshipState.friends,
      );

      final result = await repository.getRelationship('user-2');

      expect(result.userId, 'user-2');
      expect(result.state, RelationshipState.friends);
    });

    test('getRelationship translates RESOURCE_NOT_FOUND', () async {
      fakeApi.errorToThrow = const ApiException(
        statusCode: 404,
        code: 'RESOURCE_NOT_FOUND',
        message: 'Resource not found.',
      );

      try {
        await repository.getRelationship('unknown-user');
        fail('Expected SocialException');
      } on SocialException catch (e) {
        expect(e.failure.type, SocialFailureType.resourceNotFound);
      }
    });
  });
}
