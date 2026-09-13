import '../../../core/models/paged_response.dart';
import '../../../core/network/api_exception.dart';
import 'models/social_models.dart';
import 'social_api.dart';
import 'social_failure.dart';

/// Repository coordinating Social feature data operations and translating API exceptions into typed SocialExceptions.
class SocialRepository {
  final SocialApi api;

  SocialRepository({required this.api});

  Future<T> _guard<T>(Future<T> Function() work) async {
    try {
      return await work();
    } on ApiException catch (e) {
      throw SocialException(SocialFailure.fromApi(e));
    } on SocialException {
      rethrow;
    } catch (_) {
      throw const SocialException(SocialFailure(SocialFailureType.unexpected));
    }
  }

  /// Sends a friend request to [userId].
  Future<FriendRequest> sendFriendRequest(String userId) =>
      _guard(() => api.sendFriendRequest(userId));

  /// Fetches paginated received friend requests.
  Future<PagedResponse<FriendRequest>> getReceivedFriendRequests({
    int page = 0,
    int size = 30,
  }) =>
      _guard(() => api.getReceivedFriendRequests(page: page, size: size));

  /// Fetches paginated sent friend requests.
  Future<PagedResponse<FriendRequest>> getSentFriendRequests({
    int page = 0,
    int size = 30,
  }) =>
      _guard(() => api.getSentFriendRequests(page: page, size: size));

  /// Accepts incoming friend request [requestId].
  Future<FriendRequest> acceptFriendRequest(String requestId) =>
      _guard(() => api.acceptFriendRequest(requestId));

  /// Declines incoming friend request [requestId], activating 24h cooldown.
  Future<void> declineFriendRequest(String requestId) =>
      _guard(() => api.declineFriendRequest(requestId));

  /// Cancels outgoing friend request [requestId].
  Future<void> cancelFriendRequest(String requestId) =>
      _guard(() => api.cancelFriendRequest(requestId));

  /// Fetches paginated active friends list.
  Future<PagedResponse<Friend>> getFriends({
    int page = 0,
    int size = 30,
  }) =>
      _guard(() => api.getFriends(page: page, size: size));

  /// Ends friendship with [userId].
  Future<void> unfriend(String userId) => _guard(() => api.unfriend(userId));

  /// Blocks user [userId], terminating active friendship and pending requests.
  Future<void> blockUser(String userId) => _guard(() => api.blockUser(userId));

  /// Unblocks user [userId]. Does not restore friendship.
  Future<void> unblockUser(String userId) =>
      _guard(() => api.unblockUser(userId));

  /// Fetches paginated list of blocked users.
  Future<PagedResponse<BlockedUser>> getBlockedUsers({
    int page = 0,
    int size = 30,
  }) =>
      _guard(() => api.getBlockedUsers(page: page, size: size));

  /// Evaluates social relationship status with [userId] (Optional / Deviation).
  Future<RelationshipStatus> getRelationship(String userId) =>
      _guard(() => api.getRelationship(userId));
}
