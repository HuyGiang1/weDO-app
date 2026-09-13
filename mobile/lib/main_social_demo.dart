import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_colors.dart';
import 'package:mobile/core/models/paged_response.dart';
import 'package:mobile/features/social/application/social_controllers.dart';
import 'package:mobile/features/social/data/models/social_models.dart';
import 'package:mobile/features/social/data/social_api.dart';
import 'package:mobile/features/social/data/social_repository.dart';
import 'package:mobile/features/social/presentation/screens/blocked_users_screen.dart';
import 'package:mobile/features/social/presentation/screens/friend_requests_screen.dart';
import 'package:mobile/features/social/presentation/screens/friends_screen.dart';
import 'package:dio/dio.dart';

/// Interactive in-memory repository for emulator testing of M4 Social features.
class DemoSocialRepository extends SocialRepository {
  DemoSocialRepository() : super(api: SocialApi(Dio()));

  final List<Friend> _friends = [
    Friend(
      friendshipId: 'f-1',
      friend: const SocialUserSummary(
        id: 'u-1',
        username: 'lan.anh',
        displayName: 'Lan Anh',
      ),
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    ),
    Friend(
      friendshipId: 'f-2',
      friend: const SocialUserSummary(
        id: 'u-2',
        username: 'minh.tri',
        displayName: 'Minh Trí',
      ),
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    Friend(
      friendshipId: 'f-3',
      friend: const SocialUserSummary(
        id: 'u-3',
        username: 'hoang.nam',
        displayName: 'Hoàng Nam',
      ),
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  final List<FriendRequest> _received = [
    FriendRequest(
      id: 'req-rec-1',
      sender: const SocialUserSummary(
        id: 'u-4',
        username: 'thu.ha',
        displayName: 'Thu Hà',
      ),
      receiver: const SocialUserSummary(
        id: 'current-user',
        username: 'demo_user',
        displayName: 'Current User',
      ),
      status: FriendRequestStatus.pending,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    FriendRequest(
      id: 'req-rec-2',
      sender: const SocialUserSummary(
        id: 'u-5',
        username: 'quang.huy',
        displayName: 'Quang Huy',
      ),
      receiver: const SocialUserSummary(
        id: 'current-user',
        username: 'demo_user',
        displayName: 'Current User',
      ),
      status: FriendRequestStatus.pending,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
  ];

  final List<FriendRequest> _sent = [
    FriendRequest(
      id: 'req-sent-1',
      sender: const SocialUserSummary(
        id: 'current-user',
        username: 'demo_user',
        displayName: 'Current User',
      ),
      receiver: const SocialUserSummary(
        id: 'u-6',
        username: 'bao.ngoc',
        displayName: 'Bảo Ngọc',
      ),
      status: FriendRequestStatus.pending,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  final List<BlockedUser> _blocked = [
    BlockedUser(
      blockId: 'b-1',
      blockedUser: const SocialUserSummary(
        id: 'u-7',
        username: 'spammer99',
        displayName: 'Tài khoản Spam',
      ),
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
    ),
  ];

  @override
  Future<PagedResponse<Friend>> getFriends({int page = 0, int size = 30}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return PagedResponse(
      items: List.unmodifiable(_friends),
      page: page,
      size: size,
      totalElements: _friends.length,
      totalPages: 1,
      hasNext: false,
    );
  }

  @override
  Future<void> unfriend(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _friends.removeWhere((f) => f.friend.id == userId);
  }

  @override
  Future<PagedResponse<FriendRequest>> getReceivedFriendRequests({
    int page = 0,
    int size = 30,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return PagedResponse(
      items: List.unmodifiable(_received),
      page: page,
      size: size,
      totalElements: _received.length,
      totalPages: 1,
      hasNext: false,
    );
  }

  @override
  Future<PagedResponse<FriendRequest>> getSentFriendRequests({
    int page = 0,
    int size = 30,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return PagedResponse(
      items: List.unmodifiable(_sent),
      page: page,
      size: size,
      totalElements: _sent.length,
      totalPages: 1,
      hasNext: false,
    );
  }

  @override
  Future<FriendRequest> acceptFriendRequest(String requestId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _received.indexWhere((r) => r.id == requestId);
    if (index == -1) throw Exception('Request not found');
    final req = _received.removeAt(index);
    _friends.add(Friend(
      friendshipId: 'f-${DateTime.now().millisecondsSinceEpoch}',
      friend: req.sender,
      createdAt: DateTime.now(),
    ));
    return req;
  }

  @override
  Future<void> declineFriendRequest(String requestId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _received.removeWhere((r) => r.id == requestId);
  }

  @override
  Future<void> cancelFriendRequest(String requestId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _sent.removeWhere((r) => r.id == requestId);
  }

  @override
  Future<PagedResponse<BlockedUser>> getBlockedUsers({
    int page = 0,
    int size = 30,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return PagedResponse(
      items: List.unmodifiable(_blocked),
      page: page,
      size: size,
      totalElements: _blocked.length,
      totalPages: 1,
      hasNext: false,
    );
  }

  @override
  Future<void> unblockUser(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _blocked.removeWhere((b) => b.blockedUser.id == userId);
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = DemoSocialRepository();
  final friendsController = FriendsController(repository: repository);
  final requestsController = FriendRequestsController(repository: repository);
  final blockedController = BlockedUsersController(repository: repository);

  runApp(
    MaterialApp(
      title: 'weDO Social M4 Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
        ),
      ),
      home: Builder(
        builder: (context) => FriendsScreen(
          controller: friendsController,
          onOpenFriendRequests: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => FriendRequestsScreen(
                  controller: requestsController,
                ),
              ),
            );
          },
          onOpenBlockedUsers: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BlockedUsersScreen(
                  controller: blockedController,
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}
