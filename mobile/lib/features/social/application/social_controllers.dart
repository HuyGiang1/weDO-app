import 'package:flutter/foundation.dart';

import '../data/models/social_models.dart';
import '../data/social_failure.dart';
import '../data/social_repository.dart';
import 'social_state.dart';

/// Controller coordinating incoming/outgoing friend requests and request actions.
class FriendRequestsController {
  final SocialRepository repository;

  final ValueNotifier<SocialListState<FriendRequest>> receivedRequests =
      ValueNotifier(const SocialListState.initial());

  final ValueNotifier<SocialListState<FriendRequest>> sentRequests =
      ValueNotifier(const SocialListState.initial());

  final ValueNotifier<SocialActionState<dynamic>> actionState =
      ValueNotifier(const SocialActionState.idle());

  FriendRequestsController({required this.repository});

  Future<void> loadReceived({bool refresh = false}) async {
    if (!refresh && receivedRequests.value.isLoading) return;
    receivedRequests.value = const SocialListState.loading();

    try {
      final response = await repository.getReceivedFriendRequests(page: 0);
      receivedRequests.value = SocialListState(
        status: response.isEmpty
            ? SocialListStatus.empty
            : SocialListStatus.loaded,
        items: response.items,
        page: response.page,
        totalElements: response.totalElements,
        totalPages: response.totalPages,
        hasNext: response.hasNext,
      );
    } on SocialException catch (e) {
      receivedRequests.value = SocialListState(
        status: SocialListStatus.error,
        failure: e.failure,
      );
    } catch (_) {
      receivedRequests.value = const SocialListState(
        status: SocialListStatus.error,
        failure: SocialFailure(SocialFailureType.unexpected),
      );
    }
  }

  Future<void> loadMoreReceived() async {
    final current = receivedRequests.value;
    if (!current.hasNext || current.isLoadingMore || current.isLoading) return;

    receivedRequests.value =
        current.copyWith(status: SocialListStatus.loadingMore);

    try {
      final response = await repository.getReceivedFriendRequests(
        page: current.page + 1,
      );
      receivedRequests.value = current.copyWith(
        status: SocialListStatus.loaded,
        items: [...current.items, ...response.items],
        page: response.page,
        totalElements: response.totalElements,
        totalPages: response.totalPages,
        hasNext: response.hasNext,
      );
    } on SocialException catch (e) {
      receivedRequests.value = current.copyWith(
        status: SocialListStatus.errorMore,
        failure: e.failure,
      );
    } catch (_) {
      receivedRequests.value = current.copyWith(
        status: SocialListStatus.errorMore,
        failure: const SocialFailure(SocialFailureType.unexpected),
      );
    }
  }

  Future<void> loadSent({bool refresh = false}) async {
    if (!refresh && sentRequests.value.isLoading) return;
    sentRequests.value = const SocialListState.loading();

    try {
      final response = await repository.getSentFriendRequests(page: 0);
      sentRequests.value = SocialListState(
        status: response.isEmpty
            ? SocialListStatus.empty
            : SocialListStatus.loaded,
        items: response.items,
        page: response.page,
        totalElements: response.totalElements,
        totalPages: response.totalPages,
        hasNext: response.hasNext,
      );
    } on SocialException catch (e) {
      sentRequests.value = SocialListState(
        status: SocialListStatus.error,
        failure: e.failure,
      );
    } catch (_) {
      sentRequests.value = const SocialListState(
        status: SocialListStatus.error,
        failure: SocialFailure(SocialFailureType.unexpected),
      );
    }
  }

  Future<void> loadMoreSent() async {
    final current = sentRequests.value;
    if (!current.hasNext || current.isLoadingMore || current.isLoading) return;

    sentRequests.value = current.copyWith(status: SocialListStatus.loadingMore);

    try {
      final response = await repository.getSentFriendRequests(
        page: current.page + 1,
      );
      sentRequests.value = current.copyWith(
        status: SocialListStatus.loaded,
        items: [...current.items, ...response.items],
        page: response.page,
        totalElements: response.totalElements,
        totalPages: response.totalPages,
        hasNext: response.hasNext,
      );
    } on SocialException catch (e) {
      sentRequests.value = current.copyWith(
        status: SocialListStatus.errorMore,
        failure: e.failure,
      );
    } catch (_) {
      sentRequests.value = current.copyWith(
        status: SocialListStatus.errorMore,
        failure: const SocialFailure(SocialFailureType.unexpected),
      );
    }
  }

  Future<bool> sendRequest(String targetUserId) async {
    actionState.value = const SocialActionState.submitting();
    try {
      final request = await repository.sendFriendRequest(targetUserId);
      actionState.value = SocialActionState.success(request);
      return true;
    } on SocialException catch (e) {
      actionState.value = SocialActionState.error(e.failure);
      return false;
    } catch (_) {
      actionState.value = const SocialActionState.error(
        SocialFailure(SocialFailureType.unexpected),
      );
      return false;
    }
  }

  Future<bool> accept(String requestId) async {
    actionState.value = const SocialActionState.submitting();
    try {
      final response = await repository.acceptFriendRequest(requestId);
      actionState.value = SocialActionState.success(response);
      // Remove accepted request from received list
      final current = receivedRequests.value;
      final updated =
          current.items.where((req) => req.id != requestId).toList();
      receivedRequests.value = current.copyWith(
        items: updated,
        status: updated.isEmpty ? SocialListStatus.empty : current.status,
      );
      return true;
    } on SocialException catch (e) {
      actionState.value = SocialActionState.error(e.failure);
      return false;
    } catch (_) {
      actionState.value = const SocialActionState.error(
        SocialFailure(SocialFailureType.unexpected),
      );
      return false;
    }
  }

  Future<bool> decline(String requestId) async {
    actionState.value = const SocialActionState.submitting();
    try {
      await repository.declineFriendRequest(requestId);
      actionState.value = const SocialActionState.success();
      // Remove declined request from received list
      final current = receivedRequests.value;
      final updated =
          current.items.where((req) => req.id != requestId).toList();
      receivedRequests.value = current.copyWith(
        items: updated,
        status: updated.isEmpty ? SocialListStatus.empty : current.status,
      );
      return true;
    } on SocialException catch (e) {
      actionState.value = SocialActionState.error(e.failure);
      return false;
    } catch (_) {
      actionState.value = const SocialActionState.error(
        SocialFailure(SocialFailureType.unexpected),
      );
      return false;
    }
  }

  Future<bool> cancel(String requestId) async {
    actionState.value = const SocialActionState.submitting();
    try {
      await repository.cancelFriendRequest(requestId);
      actionState.value = const SocialActionState.success();
      // Remove cancelled request from sent list
      final current = sentRequests.value;
      final updated =
          current.items.where((req) => req.id != requestId).toList();
      sentRequests.value = current.copyWith(
        items: updated,
        status: updated.isEmpty ? SocialListStatus.empty : current.status,
      );
      return true;
    } on SocialException catch (e) {
      actionState.value = SocialActionState.error(e.failure);
      return false;
    } catch (_) {
      actionState.value = const SocialActionState.error(
        SocialFailure(SocialFailureType.unexpected),
      );
      return false;
    }
  }

  void resetAction() {
    actionState.value = const SocialActionState.idle();
  }

  void dispose() {
    receivedRequests.dispose();
    sentRequests.dispose();
    actionState.dispose();
  }
}

/// Controller coordinating friends list and unfriend actions.
class FriendsController {
  final SocialRepository repository;

  final ValueNotifier<SocialListState<Friend>> friends =
      ValueNotifier(const SocialListState.initial());

  final ValueNotifier<SocialActionState<dynamic>> actionState =
      ValueNotifier(const SocialActionState.idle());

  FriendsController({required this.repository});

  Future<void> loadFriends({bool refresh = false}) async {
    if (!refresh && friends.value.isLoading) return;
    friends.value = const SocialListState.loading();

    try {
      final response = await repository.getFriends(page: 0);
      friends.value = SocialListState(
        status: response.isEmpty
            ? SocialListStatus.empty
            : SocialListStatus.loaded,
        items: response.items,
        page: response.page,
        totalElements: response.totalElements,
        totalPages: response.totalPages,
        hasNext: response.hasNext,
      );
    } on SocialException catch (e) {
      friends.value = SocialListState(
        status: SocialListStatus.error,
        failure: e.failure,
      );
    } catch (_) {
      friends.value = const SocialListState(
        status: SocialListStatus.error,
        failure: SocialFailure(SocialFailureType.unexpected),
      );
    }
  }

  Future<void> loadMoreFriends() async {
    final current = friends.value;
    if (!current.hasNext || current.isLoadingMore || current.isLoading) return;

    friends.value = current.copyWith(status: SocialListStatus.loadingMore);

    try {
      final response = await repository.getFriends(page: current.page + 1);
      friends.value = current.copyWith(
        status: SocialListStatus.loaded,
        items: [...current.items, ...response.items],
        page: response.page,
        totalElements: response.totalElements,
        totalPages: response.totalPages,
        hasNext: response.hasNext,
      );
    } on SocialException catch (e) {
      friends.value = current.copyWith(
        status: SocialListStatus.errorMore,
        failure: e.failure,
      );
    } catch (_) {
      friends.value = current.copyWith(
        status: SocialListStatus.errorMore,
        failure: const SocialFailure(SocialFailureType.unexpected),
      );
    }
  }

  Future<bool> unfriend(String userId) async {
    actionState.value = const SocialActionState.submitting();
    try {
      await repository.unfriend(userId);
      actionState.value = const SocialActionState.success();
      // Remove friend from list
      final current = friends.value;
      final updated =
          current.items.where((f) => f.friend.id != userId).toList();
      friends.value = current.copyWith(
        items: updated,
        status: updated.isEmpty ? SocialListStatus.empty : current.status,
      );
      return true;
    } on SocialException catch (e) {
      actionState.value = SocialActionState.error(e.failure);
      return false;
    } catch (_) {
      actionState.value = const SocialActionState.error(
        SocialFailure(SocialFailureType.unexpected),
      );
      return false;
    }
  }

  void resetAction() {
    actionState.value = const SocialActionState.idle();
  }

  void dispose() {
    friends.dispose();
    actionState.dispose();
  }
}

/// Controller coordinating blocked users list and block/unblock actions.
class BlockedUsersController {
  final SocialRepository repository;

  final ValueNotifier<SocialListState<BlockedUser>> blockedUsers =
      ValueNotifier(const SocialListState.initial());

  final ValueNotifier<SocialActionState<dynamic>> actionState =
      ValueNotifier(const SocialActionState.idle());

  BlockedUsersController({required this.repository});

  Future<void> loadBlockedUsers({bool refresh = false}) async {
    if (!refresh && blockedUsers.value.isLoading) return;
    blockedUsers.value = const SocialListState.loading();

    try {
      final response = await repository.getBlockedUsers(page: 0);
      blockedUsers.value = SocialListState(
        status: response.isEmpty
            ? SocialListStatus.empty
            : SocialListStatus.loaded,
        items: response.items,
        page: response.page,
        totalElements: response.totalElements,
        totalPages: response.totalPages,
        hasNext: response.hasNext,
      );
    } on SocialException catch (e) {
      blockedUsers.value = SocialListState(
        status: SocialListStatus.error,
        failure: e.failure,
      );
    } catch (_) {
      blockedUsers.value = const SocialListState(
        status: SocialListStatus.error,
        failure: SocialFailure(SocialFailureType.unexpected),
      );
    }
  }

  Future<void> loadMoreBlockedUsers() async {
    final current = blockedUsers.value;
    if (!current.hasNext || current.isLoadingMore || current.isLoading) return;

    blockedUsers.value =
        current.copyWith(status: SocialListStatus.loadingMore);

    try {
      final response = await repository.getBlockedUsers(page: current.page + 1);
      blockedUsers.value = current.copyWith(
        status: SocialListStatus.loaded,
        items: [...current.items, ...response.items],
        page: response.page,
        totalElements: response.totalElements,
        totalPages: response.totalPages,
        hasNext: response.hasNext,
      );
    } on SocialException catch (e) {
      blockedUsers.value = current.copyWith(
        status: SocialListStatus.errorMore,
        failure: e.failure,
      );
    } catch (_) {
      blockedUsers.value = current.copyWith(
        status: SocialListStatus.errorMore,
        failure: const SocialFailure(SocialFailureType.unexpected),
      );
    }
  }

  Future<bool> block(String userId) async {
    actionState.value = const SocialActionState.submitting();
    try {
      await repository.blockUser(userId);
      actionState.value = const SocialActionState.success();
      return true;
    } on SocialException catch (e) {
      actionState.value = SocialActionState.error(e.failure);
      return false;
    } catch (_) {
      actionState.value = const SocialActionState.error(
        SocialFailure(SocialFailureType.unexpected),
      );
      return false;
    }
  }

  Future<bool> unblock(String userId) async {
    actionState.value = const SocialActionState.submitting();
    try {
      await repository.unblockUser(userId);
      actionState.value = const SocialActionState.success();
      // Remove unblocked user from blocked list
      final current = blockedUsers.value;
      final updated =
          current.items.where((b) => b.blockedUser.id != userId).toList();
      blockedUsers.value = current.copyWith(
        items: updated,
        status: updated.isEmpty ? SocialListStatus.empty : current.status,
      );
      return true;
    } on SocialException catch (e) {
      actionState.value = SocialActionState.error(e.failure);
      return false;
    } catch (_) {
      actionState.value = const SocialActionState.error(
        SocialFailure(SocialFailureType.unexpected),
      );
      return false;
    }
  }

  void resetAction() {
    actionState.value = const SocialActionState.idle();
  }

  void dispose() {
    blockedUsers.dispose();
    actionState.dispose();
  }
}
