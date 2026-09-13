import 'package:dio/dio.dart';

import '../../../core/models/paged_response.dart';
import '../../../core/network/api_exception.dart';
import 'models/social_models.dart';

/// HTTP client wrapper for M4 Social endpoints.
class SocialApi {
  final Dio dio;

  SocialApi(this.dio);

  Future<T> _call<T>(
    Future<Response<dynamic>> Function() request,
    T Function(Map<String, dynamic>) parse,
  ) async {
    try {
      final response = await request();
      final data = response.data;
      if (data is! Map) throw const FormatException('Expected JSON object');
      try {
        return parse(Map<String, dynamic>.from(data));
      } on FormatException {
        rethrow;
      } catch (e) {
        throw FormatException('Malformed response payload: $e');
      }
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> _empty(Future<Response<dynamic>> Function() request) async {
    try {
      await request();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  // SOCIAL-01: Send Friend Request
  Future<FriendRequest> sendFriendRequest(String userId) => _call(
        () => dio.post(
          '/api/v1/users/${Uri.encodeComponent(userId)}/friend-requests',
        ),
        FriendRequest.fromJson,
      );

  // SOCIAL-02: Received Friend Requests
  Future<PagedResponse<FriendRequest>> getReceivedFriendRequests({
    int page = 0,
    int size = 30,
  }) =>
      _call(
        () => dio.get(
          '/api/v1/me/friend-requests',
          queryParameters: {
            'direction': 'received',
            'page': page,
            'size': size,
          },
        ),
        (json) => PagedResponse.fromJson(json, FriendRequest.fromJson),
      );

  // SOCIAL-03: Sent Friend Requests
  Future<PagedResponse<FriendRequest>> getSentFriendRequests({
    int page = 0,
    int size = 30,
  }) =>
      _call(
        () => dio.get(
          '/api/v1/me/friend-requests',
          queryParameters: {
            'direction': 'sent',
            'page': page,
            'size': size,
          },
        ),
        (json) => PagedResponse.fromJson(json, FriendRequest.fromJson),
      );

  // SOCIAL-04: Accept Friend Request
  Future<FriendRequest> acceptFriendRequest(String requestId) => _call(
        () => dio.post(
          '/api/v1/friend-requests/${Uri.encodeComponent(requestId)}/accept',
        ),
        FriendRequest.fromJson,
      );

  // SOCIAL-05: Decline Friend Request
  Future<void> declineFriendRequest(String requestId) => _empty(
        () => dio.post(
          '/api/v1/friend-requests/${Uri.encodeComponent(requestId)}/decline',
        ),
      );

  // SOCIAL-06: Cancel Friend Request
  Future<void> cancelFriendRequest(String requestId) => _empty(
        () => dio.post(
          '/api/v1/friend-requests/${Uri.encodeComponent(requestId)}/cancel',
        ),
      );

  // SOCIAL-07: Friends List
  Future<PagedResponse<Friend>> getFriends({
    int page = 0,
    int size = 30,
  }) =>
      _call(
        () => dio.get(
          '/api/v1/me/friends',
          queryParameters: {
            'page': page,
            'size': size,
          },
        ),
        (json) => PagedResponse.fromJson(json, Friend.fromJson),
      );

  // SOCIAL-08: Unfriend
  Future<void> unfriend(String userId) => _empty(
        () => dio.delete(
          '/api/v1/friends/${Uri.encodeComponent(userId)}',
        ),
      );

  // SOCIAL-09: Block User
  Future<void> blockUser(String userId) => _empty(
        () => dio.post(
          '/api/v1/users/${Uri.encodeComponent(userId)}/block',
        ),
      );

  // SOCIAL-10: Unblock User
  Future<void> unblockUser(String userId) => _empty(
        () => dio.delete(
          '/api/v1/users/${Uri.encodeComponent(userId)}/block',
        ),
      );

  // SOCIAL-11: Blocked Users
  Future<PagedResponse<BlockedUser>> getBlockedUsers({
    int page = 0,
    int size = 30,
  }) =>
      _call(
        () => dio.get(
          '/api/v1/me/blocked-users',
          queryParameters: {
            'page': page,
            'size': size,
          },
        ),
        (json) => PagedResponse.fromJson(json, BlockedUser.fromJson),
      );

  // SOCIAL-12 (Optional / Deviation): Relationship Status
  Future<RelationshipStatus> getRelationship(String userId) => _call(
        () => dio.get(
          '/api/v1/users/${Uri.encodeComponent(userId)}/relationship',
        ),
        RelationshipStatus.fromJson,
      );
}
