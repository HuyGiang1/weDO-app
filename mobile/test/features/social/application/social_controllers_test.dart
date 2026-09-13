import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/paged_response.dart';
import 'package:mobile/features/social/application/social_controllers.dart';
import 'package:mobile/features/social/data/models/social_models.dart';
import 'package:mobile/features/social/data/social_api.dart';
import 'package:mobile/features/social/data/social_failure.dart';
import 'package:mobile/features/social/data/social_repository.dart';

class MockSocialRepository extends SocialRepository {
  MockSocialRepository() : super(api: SocialApi(Dio()));

  FriendRequest? sendResult;
  PagedResponse<FriendRequest>? receivedResult;
  PagedResponse<FriendRequest>? sentResult;
  FriendRequest? acceptResult;
  PagedResponse<Friend>? friendsResult;
  PagedResponse<BlockedUser>? blockedResult;

  SocialFailure? errorToThrow;

  @override
  Future<FriendRequest> sendFriendRequest(String userId) async {
    if (errorToThrow != null) throw SocialException(errorToThrow!);
    return sendResult!;
  }

  @override
  Future<PagedResponse<FriendRequest>> getReceivedFriendRequests({
    int page = 0,
    int size = 30,
  }) async {
    if (errorToThrow != null) throw SocialException(errorToThrow!);
    return receivedResult!;
  }

  @override
  Future<PagedResponse<FriendRequest>> getSentFriendRequests({
    int page = 0,
    int size = 30,
  }) async {
    if (errorToThrow != null) throw SocialException(errorToThrow!);
    return sentResult!;
  }

  @override
  Future<FriendRequest> acceptFriendRequest(String requestId) async {
    if (errorToThrow != null) throw SocialException(errorToThrow!);
    return acceptResult!;
  }

  @override
  Future<void> declineFriendRequest(String requestId) async {
    if (errorToThrow != null) throw SocialException(errorToThrow!);
  }

  @override
  Future<void> cancelFriendRequest(String requestId) async {
    if (errorToThrow != null) throw SocialException(errorToThrow!);
  }

  @override
  Future<PagedResponse<Friend>> getFriends({
    int page = 0,
    int size = 30,
  }) async {
    if (errorToThrow != null) throw SocialException(errorToThrow!);
    return friendsResult!;
  }

  @override
  Future<void> unfriend(String userId) async {
    if (errorToThrow != null) throw SocialException(errorToThrow!);
  }

  @override
  Future<void> blockUser(String userId) async {
    if (errorToThrow != null) throw SocialException(errorToThrow!);
  }

  @override
  Future<void> unblockUser(String userId) async {
    if (errorToThrow != null) throw SocialException(errorToThrow!);
  }

  @override
  Future<PagedResponse<BlockedUser>> getBlockedUsers({
    int page = 0,
    int size = 30,
  }) async {
    if (errorToThrow != null) throw SocialException(errorToThrow!);
    return blockedResult!;
  }
}

void main() {
  late MockSocialRepository repository;

  final user1 = const SocialUserSummary(
    id: 'u1',
    username: 'alice',
    displayName: 'Alice',
  );
  final user2 = const SocialUserSummary(
    id: 'u2',
    username: 'bob',
    displayName: 'Bob',
  );

  final sampleRequest = FriendRequest(
    id: 'req-1',
    sender: user1,
    receiver: user2,
    status: FriendRequestStatus.pending,
    createdAt: DateTime.parse('2026-09-13T10:00:00Z'),
  );

  setUp(() {
    repository = MockSocialRepository();
  });

  group('FriendRequestsController State Transitions', () {
    late FriendRequestsController controller;

    setUp(() {
      controller = FriendRequestsController(repository: repository);
    });

    tearDown(() {
      controller.dispose();
    });

    test('initial state is initial', () {
      expect(controller.receivedRequests.value.isInitial, isTrue);
      expect(controller.sentRequests.value.isInitial, isTrue);
      expect(controller.actionState.value.isIdle, isTrue);
    });

    test('loadReceived transitions initial -> loading -> loaded', () async {
      repository.receivedResult = PagedResponse(
        items: [sampleRequest],
        page: 0,
        size: 30,
        totalElements: 1,
        totalPages: 1,
        hasNext: false,
      );

      final future = controller.loadReceived();
      expect(controller.receivedRequests.value.isLoading, isTrue);

      await future;

      expect(controller.receivedRequests.value.isLoaded, isTrue);
      expect(controller.receivedRequests.value.items.length, 1);
      expect(controller.receivedRequests.value.items.first.id, 'req-1');
    });

    test('loadReceived transitions to empty when items is empty', () async {
      repository.receivedResult = const PagedResponse(
        items: [],
        page: 0,
        size: 30,
        totalElements: 0,
        totalPages: 0,
        hasNext: false,
      );

      await controller.loadReceived();

      expect(controller.receivedRequests.value.isEmpty, isTrue);
      expect(controller.receivedRequests.value.items, isEmpty);
    });

    test('loadReceived transitions to error on failure', () async {
      repository.errorToThrow = const SocialFailure(
        SocialFailureType.network,
        backendMessage: 'Connection failed',
      );

      await controller.loadReceived();

      expect(controller.receivedRequests.value.isError, isTrue);
      expect(
        controller.receivedRequests.value.failure?.type,
        SocialFailureType.network,
      );
    });

    test('loadMoreReceived appends next page items', () async {
      repository.receivedResult = PagedResponse(
        items: [sampleRequest],
        page: 0,
        size: 1,
        totalElements: 2,
        totalPages: 2,
        hasNext: true,
      );
      await controller.loadReceived();
      expect(controller.receivedRequests.value.items.length, 1);

      final secondRequest = FriendRequest(
        id: 'req-2',
        sender: user2,
        receiver: user1,
        status: FriendRequestStatus.pending,
        createdAt: DateTime.parse('2026-09-13T10:05:00Z'),
      );
      repository.receivedResult = PagedResponse(
        items: [secondRequest],
        page: 1,
        size: 1,
        totalElements: 2,
        totalPages: 2,
        hasNext: false,
      );

      await controller.loadMoreReceived();

      expect(controller.receivedRequests.value.items.length, 2);
      expect(controller.receivedRequests.value.hasNext, isFalse);
    });

    test('sendRequest transitions idle -> submitting -> success', () async {
      repository.sendResult = sampleRequest;

      final success = await controller.sendRequest('u2');

      expect(success, isTrue);
      expect(controller.actionState.value.isSuccess, isTrue);
      expect(controller.actionState.value.data, sampleRequest);
    });

    test('sendRequest handles error and sets action failure', () async {
      repository.errorToThrow = const SocialFailure(
        SocialFailureType.friendRequestCooldownActive,
        backendCode: 'FRIEND_REQUEST_COOLDOWN_ACTIVE',
      );

      final success = await controller.sendRequest('u2');

      expect(success, isFalse);
      expect(controller.actionState.value.isError, isTrue);
      expect(
        controller.actionState.value.failure?.type,
        SocialFailureType.friendRequestCooldownActive,
      );
    });

    test('accept removes accepted request from received list', () async {
      repository.receivedResult = PagedResponse(
        items: [sampleRequest],
        page: 0,
        size: 30,
        totalElements: 1,
        totalPages: 1,
        hasNext: false,
      );
      await controller.loadReceived();
      expect(controller.receivedRequests.value.items.length, 1);

      final accepted = FriendRequest(
        id: 'req-1',
        sender: user1,
        receiver: user2,
        status: FriendRequestStatus.accepted,
        createdAt: DateTime.parse('2026-09-13T10:00:00Z'),
      );
      repository.acceptResult = accepted;

      final ok = await controller.accept('req-1');

      expect(ok, isTrue);
      expect(controller.receivedRequests.value.items, isEmpty);
      expect(controller.receivedRequests.value.isEmpty, isTrue);
    });

    test('decline removes declined request from received list', () async {
      repository.receivedResult = PagedResponse(
        items: [sampleRequest],
        page: 0,
        size: 30,
        totalElements: 1,
        totalPages: 1,
        hasNext: false,
      );
      await controller.loadReceived();

      final ok = await controller.decline('req-1');

      expect(ok, isTrue);
      expect(controller.receivedRequests.value.items, isEmpty);
    });

    test('cancel removes cancelled request from sent list', () async {
      repository.sentResult = PagedResponse(
        items: [sampleRequest],
        page: 0,
        size: 30,
        totalElements: 1,
        totalPages: 1,
        hasNext: false,
      );
      await controller.loadSent();
      expect(controller.sentRequests.value.items.length, 1);

      final ok = await controller.cancel('req-1');

      expect(ok, isTrue);
      expect(controller.sentRequests.value.items, isEmpty);
    });
  });

  group('FriendsController State Transitions', () {
    late FriendsController controller;

    setUp(() {
      controller = FriendsController(repository: repository);
    });

    tearDown(() {
      controller.dispose();
    });

    test('loadFriends transitions initial -> loading -> loaded', () async {
      repository.friendsResult = PagedResponse(
        items: [
          Friend(
            friendshipId: 'fs-1',
            friend: user2,
            createdAt: DateTime.parse('2026-09-13T10:00:00Z'),
          ),
        ],
        page: 0,
        size: 30,
        totalElements: 1,
        totalPages: 1,
        hasNext: false,
      );

      await controller.loadFriends();

      expect(controller.friends.value.isLoaded, isTrue);
      expect(controller.friends.value.items.length, 1);
    });

    test('unfriend removes friend from items list', () async {
      repository.friendsResult = PagedResponse(
        items: [
          Friend(
            friendshipId: 'fs-1',
            friend: user2,
            createdAt: DateTime.parse('2026-09-13T10:00:00Z'),
          ),
        ],
        page: 0,
        size: 30,
        totalElements: 1,
        totalPages: 1,
        hasNext: false,
      );
      await controller.loadFriends();
      expect(controller.friends.value.items.length, 1);

      final ok = await controller.unfriend('u2');

      expect(ok, isTrue);
      expect(controller.friends.value.items, isEmpty);
      expect(controller.friends.value.isEmpty, isTrue);
    });
  });

  group('BlockedUsersController State Transitions', () {
    late BlockedUsersController controller;

    setUp(() {
      controller = BlockedUsersController(repository: repository);
    });

    tearDown(() {
      controller.dispose();
    });

    test('loadBlockedUsers transitions initial -> loading -> loaded', () async {
      repository.blockedResult = PagedResponse(
        items: [
          BlockedUser(
            blockId: 'b-1',
            blockedUser: user2,
            createdAt: DateTime.parse('2026-09-13T10:00:00Z'),
          ),
        ],
        page: 0,
        size: 30,
        totalElements: 1,
        totalPages: 1,
        hasNext: false,
      );

      await controller.loadBlockedUsers();

      expect(controller.blockedUsers.value.isLoaded, isTrue);
      expect(controller.blockedUsers.value.items.length, 1);
    });

    test('block succeeds and updates actionState', () async {
      final ok = await controller.block('u2');

      expect(ok, isTrue);
      expect(controller.actionState.value.isSuccess, isTrue);
    });

    test('unblock removes unblocked user from list', () async {
      repository.blockedResult = PagedResponse(
        items: [
          BlockedUser(
            blockId: 'b-1',
            blockedUser: user2,
            createdAt: DateTime.parse('2026-09-13T10:00:00Z'),
          ),
        ],
        page: 0,
        size: 30,
        totalElements: 1,
        totalPages: 1,
        hasNext: false,
      );
      await controller.loadBlockedUsers();
      expect(controller.blockedUsers.value.items.length, 1);

      final ok = await controller.unblock('u2');

      expect(ok, isTrue);
      expect(controller.blockedUsers.value.items, isEmpty);
      expect(controller.blockedUsers.value.isEmpty, isTrue);
    });
  });
}
