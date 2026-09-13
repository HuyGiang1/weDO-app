import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/social/data/models/social_models.dart';
import 'package:mobile/features/social/data/social_api.dart';
import 'package:mobile/features/social/data/social_failure.dart';

void main() {
  late RecordingAdapter adapter;
  late SocialApi api;

  setUp(() {
    adapter = RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://test'))
      ..httpClientAdapter = adapter;
    api = SocialApi(dio);
  });

  group('SocialApi Endpoint & Contract Verification', () {
    test('SOCIAL-01 sendFriendRequest uses POST with target userId in path', () async {
      adapter.responses['/api/v1/users/target-123/friend-requests'] = {
        'id': 'req-1',
        'sender': {
          'id': 'my-user-id',
          'username': 'me',
          'displayName': 'Myself',
          'avatarStorageKey': null,
        },
        'receiver': {
          'id': 'target-123',
          'username': 'target',
          'displayName': 'Target',
          'avatarStorageKey': null,
        },
        'status': 'PENDING',
        'createdAt': '2026-09-13T10:00:00Z',
        'respondedAt': null,
      };

      final result = await api.sendFriendRequest('target-123');

      final req = adapter.byPath('/api/v1/users/target-123/friend-requests');
      expect(req.method, 'POST');
      expect(result.id, 'req-1');
      expect(result.sender.id, 'my-user-id');
      expect(result.receiver.id, 'target-123');
      expect(result.status, FriendRequestStatus.pending);
    });

    test('SOCIAL-02 getReceivedFriendRequests uses GET with direction=received', () async {
      adapter.responses['/api/v1/me/friend-requests'] = {
        'items': [
          {
            'id': 'req-1',
            'sender': {
              'id': 'sender-1',
              'username': 'sender',
              'displayName': 'Sender',
            },
            'receiver': {
              'id': 'my-id',
              'username': 'me',
              'displayName': 'Me',
            },
            'status': 'PENDING',
            'createdAt': '2026-09-13T10:00:00Z',
            'respondedAt': null,
          }
        ],
        'page': 0,
        'size': 30,
        'totalElements': 1,
        'totalPages': 1,
        'hasNext': false,
      };

      final result = await api.getReceivedFriendRequests(page: 0, size: 30);

      final req = adapter.byPath('/api/v1/me/friend-requests');
      expect(req.method, 'GET');
      expect(req.queryParameters['direction'], 'received');
      expect(req.queryParameters['page'], 0);
      expect(req.queryParameters['size'], 30);
      expect(result.items.length, 1);
      expect(result.items.first.sender.username, 'sender');
    });

    test('SOCIAL-03 getSentFriendRequests uses GET with direction=sent', () async {
      adapter.responses['/api/v1/me/friend-requests'] = {
        'items': <dynamic>[],
        'page': 1,
        'size': 20,
        'totalElements': 0,
        'totalPages': 0,
        'hasNext': false,
      };

      final result = await api.getSentFriendRequests(page: 1, size: 20);

      final req = adapter.byPath('/api/v1/me/friend-requests');
      expect(req.method, 'GET');
      expect(req.queryParameters['direction'], 'sent');
      expect(req.queryParameters['page'], 1);
      expect(req.queryParameters['size'], 20);
      expect(result.items, isEmpty);
    });

    test('SOCIAL-04 acceptFriendRequest uses POST and parses updated request', () async {
      adapter.responses['/api/v1/friend-requests/req-10/accept'] = {
        'id': 'req-10',
        'sender': {'id': 'u1', 'username': 'u1', 'displayName': 'User 1'},
        'receiver': {'id': 'u2', 'username': 'u2', 'displayName': 'User 2'},
        'status': 'ACCEPTED',
        'createdAt': '2026-09-13T10:00:00Z',
        'respondedAt': '2026-09-13T10:05:00Z',
      };

      final result = await api.acceptFriendRequest('req-10');

      final req = adapter.byPath('/api/v1/friend-requests/req-10/accept');
      expect(req.method, 'POST');
      expect(result.status, FriendRequestStatus.accepted);
    });

    test('SOCIAL-05 declineFriendRequest uses POST with empty response', () async {
      adapter.responses['/api/v1/friend-requests/req-10/decline'] = null;

      await api.declineFriendRequest('req-10');

      final req = adapter.byPath('/api/v1/friend-requests/req-10/decline');
      expect(req.method, 'POST');
    });

    test('SOCIAL-06 cancelFriendRequest uses POST with empty response', () async {
      adapter.responses['/api/v1/friend-requests/req-10/cancel'] = null;

      await api.cancelFriendRequest('req-10');

      final req = adapter.byPath('/api/v1/friend-requests/req-10/cancel');
      expect(req.method, 'POST');
    });

    test('SOCIAL-07 getFriends uses GET with page and size parameters', () async {
      adapter.responses['/api/v1/me/friends'] = {
        'items': [
          {
            'friendshipId': 'fs-1',
            'friend': {'id': 'f1', 'username': 'friend1', 'displayName': 'Friend One'},
            'createdAt': '2026-09-13T10:00:00Z',
          }
        ],
        'page': 0,
        'size': 30,
        'totalElements': 1,
        'totalPages': 1,
        'hasNext': false,
      };

      final result = await api.getFriends(page: 0, size: 30);

      final req = adapter.byPath('/api/v1/me/friends');
      expect(req.method, 'GET');
      expect(req.queryParameters['page'], 0);
      expect(req.queryParameters['size'], 30);
      expect(result.items.first.friend.username, 'friend1');
    });

    test('SOCIAL-08 unfriend uses DELETE with userId in path', () async {
      adapter.responses['/api/v1/friends/friend-123'] = null;

      await api.unfriend('friend-123');

      final req = adapter.byPath('/api/v1/friends/friend-123');
      expect(req.method, 'DELETE');
    });

    test('SOCIAL-09 blockUser uses POST with userId in path', () async {
      adapter.responses['/api/v1/users/bad-actor/block'] = null;

      await api.blockUser('bad-actor');

      final req = adapter.byPath('/api/v1/users/bad-actor/block');
      expect(req.method, 'POST');
    });

    test('SOCIAL-10 unblockUser uses DELETE with userId in path', () async {
      adapter.responses['/api/v1/users/bad-actor/block'] = null;

      await api.unblockUser('bad-actor');

      final req = adapter.byPath('/api/v1/users/bad-actor/block');
      expect(req.method, 'DELETE');
    });

    test('SOCIAL-11 getBlockedUsers uses GET with pagination', () async {
      adapter.responses['/api/v1/me/blocked-users'] = {
        'items': [
          {
            'blockId': 'b-1',
            'blockedUser': {'id': 'u-bad', 'username': 'bad', 'displayName': 'Bad Guy'},
            'createdAt': '2026-09-13T10:00:00Z',
          }
        ],
        'page': 0,
        'size': 30,
        'totalElements': 1,
        'totalPages': 1,
        'hasNext': false,
      };

      final result = await api.getBlockedUsers(page: 0, size: 30);

      final req = adapter.byPath('/api/v1/me/blocked-users');
      expect(req.method, 'GET');
      expect(result.items.first.blockedUser.username, 'bad');
    });

    test('SOCIAL-12 getRelationship (Deviation / Optional) returns relationship status', () async {
      adapter.responses['/api/v1/users/target-1/relationship'] = {
        'userId': 'target-1',
        'state': 'FRIENDS',
      };

      final result = await api.getRelationship('target-1');

      final req = adapter.byPath('/api/v1/users/target-1/relationship');
      expect(req.method, 'GET');
      expect(result.userId, 'target-1');
      expect(result.state, RelationshipState.friends);
    });
  });

  group('SocialApi Error Code Preservation', () {
    test('preserves CANNOT_FRIEND_SELF code and status 400', () async {
      adapter.status = 400;
      adapter.responses['/api/v1/users/self/friend-requests'] = {
        'code': 'CANNOT_FRIEND_SELF',
        'message': 'Cannot send friend request to yourself.',
      };

      try {
        await api.sendFriendRequest('self');
        fail('Expected ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 400);
        expect(e.code, 'CANNOT_FRIEND_SELF');
        expect(SocialFailure.fromApi(e).type, SocialFailureType.cannotFriendSelf);
      }
    });

    test('preserves USER_BLOCKED code and status 403', () async {
      adapter.status = 403;
      adapter.responses['/api/v1/users/blocked-user/friend-requests'] = {
        'code': 'USER_BLOCKED',
        'message': 'User is blocked.',
      };

      try {
        await api.sendFriendRequest('blocked-user');
        fail('Expected ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 403);
        expect(e.code, 'USER_BLOCKED');
        expect(SocialFailure.fromApi(e).type, SocialFailureType.userBlocked);
      }
    });

    test('preserves ALREADY_FRIENDS code and status 409', () async {
      adapter.status = 409;
      adapter.responses['/api/v1/users/friend-user/friend-requests'] = {
        'code': 'ALREADY_FRIENDS',
        'message': 'Users are already friends.',
      };

      try {
        await api.sendFriendRequest('friend-user');
        fail('Expected ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 409);
        expect(e.code, 'ALREADY_FRIENDS');
        expect(SocialFailure.fromApi(e).type, SocialFailureType.alreadyFriends);
      }
    });

    test('preserves FRIEND_REQUEST_ALREADY_PENDING code and status 409', () async {
      adapter.status = 409;
      adapter.responses['/api/v1/users/target/friend-requests'] = {
        'code': 'FRIEND_REQUEST_ALREADY_PENDING',
        'message': 'A friend request is already pending.',
      };

      try {
        await api.sendFriendRequest('target');
        fail('Expected ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 409);
        expect(e.code, 'FRIEND_REQUEST_ALREADY_PENDING');
        expect(
          SocialFailure.fromApi(e).type,
          SocialFailureType.friendRequestAlreadyPending,
        );
      }
    });

    test('preserves FRIEND_REQUEST_COOLDOWN_ACTIVE code and status 429', () async {
      adapter.status = 429;
      adapter.responses['/api/v1/users/target/friend-requests'] = {
        'code': 'FRIEND_REQUEST_COOLDOWN_ACTIVE',
        'message': 'Please wait before sending another friend request.',
      };

      try {
        await api.sendFriendRequest('target');
        fail('Expected ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 429);
        expect(e.code, 'FRIEND_REQUEST_COOLDOWN_ACTIVE');
        expect(
          SocialFailure.fromApi(e).type,
          SocialFailureType.friendRequestCooldownActive,
        );
      }
    });

    test('preserves FRIEND_REQUEST_NOT_ALLOWED code and status 403', () async {
      adapter.status = 403;
      adapter.responses['/api/v1/users/private-user/friend-requests'] = {
        'code': 'FRIEND_REQUEST_NOT_ALLOWED',
        'message': 'User privacy settings do not allow friend requests.',
      };

      try {
        await api.sendFriendRequest('private-user');
        fail('Expected ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 403);
        expect(e.code, 'FRIEND_REQUEST_NOT_ALLOWED');
        expect(
          SocialFailure.fromApi(e).type,
          SocialFailureType.friendRequestNotAllowed,
        );
      }
    });

    test('preserves CANNOT_BLOCK_SELF code and status 400', () async {
      adapter.status = 400;
      adapter.responses['/api/v1/users/self/block'] = {
        'code': 'CANNOT_BLOCK_SELF',
        'message': 'Cannot block yourself.',
      };

      try {
        await api.blockUser('self');
        fail('Expected ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 400);
        expect(e.code, 'CANNOT_BLOCK_SELF');
        expect(SocialFailure.fromApi(e).type, SocialFailureType.cannotBlockSelf);
      }
    });

    test('maps connection errors to network failure', () async {
      adapter.throwConnection = true;

      try {
        await api.getFriends();
        fail('Expected ApiException');
      } on ApiException catch (e) {
        expect(e.transportFailure, ApiTransportFailure.network);
        expect(SocialFailure.fromApi(e).type, SocialFailureType.network);
      }
    });
  });
}

class RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final responses = <String, dynamic>{};
  int status = 200;
  bool throwConnection = false;

  RequestOptions byPath(String p) => requests.firstWhere((r) => r.path == p);

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    requests.add(o);
    if (throwConnection) {
      throw DioException(
        requestOptions: o,
        type: DioExceptionType.connectionError,
      );
    }
    return ResponseBody.fromString(
      jsonEncode(responses[o.path] ?? {}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
