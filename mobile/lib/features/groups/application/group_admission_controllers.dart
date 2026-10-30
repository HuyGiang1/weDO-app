import 'package:flutter/foundation.dart';

import '../data/group_failure.dart';
import '../data/group_repository.dart';
import '../data/models/group_models.dart';
import 'group_management_controllers.dart';

class GroupInvitationsController
    extends ValueNotifier<GroupAsyncState<List<GroupInvitationResponse>>> {
  final GroupRepository repository;
  GroupInvitationsController(this.repository) : super(const GroupAsyncState());

  Future<void> load() async {
    value = const GroupAsyncState(loading: true);
    try {
      final res = await repository.listMyInvitations();
      value = GroupAsyncState(data: res.items);
    } on GroupException catch (e) {
      value = GroupAsyncState(failure: e.failure);
    }
  }

  Future<bool> accept(String id) async {
    try {
      await repository.acceptInvitation(id);
      await load();
      return true;
    } on GroupException catch (e) {
      value = GroupAsyncState(data: value.data, failure: e.failure);
      return false;
    }
  }

  Future<bool> decline(String id) async {
    try {
      await repository.declineInvitation(id);
      await load();
      return true;
    } on GroupException catch (e) {
      value = GroupAsyncState(data: value.data, failure: e.failure);
      return false;
    }
  }
}

class InviteLinksController
    extends ValueNotifier<GroupAsyncState<List<InviteLinkResponse>>> {
  final GroupRepository repository;
  InviteLinksController(this.repository) : super(const GroupAsyncState());

  Future<void> load(String groupId) async {
    value = const GroupAsyncState(loading: true);
    try {
      final list = await repository.listInviteLinks(groupId);
      value = GroupAsyncState(data: list);
    } on GroupException catch (e) {
      value = GroupAsyncState(failure: e.failure);
    }
  }

  Future<InviteLinkResponse?> getDefault(String groupId) async {
    try {
      return await repository.getDefaultInviteLink(groupId);
    } on GroupException catch (e) {
      value = GroupAsyncState(data: value.data, failure: e.failure);
      return null;
    }
  }

  Future<InviteLinkResponse?> create(
    String groupId,
    CreateInviteLinkRequest request,
  ) async {
    value = GroupAsyncState(loading: true, data: value.data);
    try {
      final created = await repository.createInviteLink(groupId, request);
      await load(groupId);
      return created;
    } on GroupException catch (e) {
      value = GroupAsyncState(data: value.data, failure: e.failure);
      return null;
    }
  }

  Future<bool> revoke(String groupId, String linkId) async {
    try {
      await repository.revokeInviteLink(linkId);
      await load(groupId);
      return true;
    } on GroupException catch (e) {
      value = GroupAsyncState(data: value.data, failure: e.failure);
      return false;
    }
  }
}

class JoinByCodeController
    extends ValueNotifier<GroupAsyncState<GroupInviteSummaryResponse>> {
  final GroupRepository repository;
  int _generation = 0;
  bool _disposed = false;
  JoinByCodeController(this.repository) : super(const GroupAsyncState());

  Future<GroupInviteSummaryResponse?> resolve(String code) async {
    if (_disposed) return null;
    final generation = ++_generation;
    value = const GroupAsyncState(loading: true);
    try {
      final summary = await repository.resolveInviteCode(code);
      if (_disposed || generation != _generation) return null;
      value = GroupAsyncState(data: summary);
      return summary;
    } on GroupException catch (e) {
      if (!_disposed && generation == _generation) value = GroupAsyncState(failure: e.failure);
      return null;
    }
  }

  Future<bool> join(String code) async {
    if (_disposed || value.loading || value.data?.alreadyMember == true || value.data?.requestPending == true) return false;
    final generation = ++_generation;
    value = GroupAsyncState(loading: true, data: value.data);
    try {
      await repository.joinViaInviteCode(code);
      if (_disposed || generation != _generation) return false;
      value = GroupAsyncState(data: value.data);
      return true;
    } on GroupException catch (e) {
      if (_disposed || generation != _generation) return false;
      if (e.failure.type == GroupFailureType.alreadyGroupMember ||
          e.failure.type == GroupFailureType.joinRequestAlreadyPending) {
        await resolve(code); // State may have changed on another device; never replay the mutation.
      } else {
        value = GroupAsyncState(data: value.data, failure: e.failure);
      }
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

class JoinRequestsController
    extends ValueNotifier<GroupAsyncState<List<JoinRequestResponse>>> {
  final GroupRepository repository;
  JoinRequestsController(this.repository) : super(const GroupAsyncState());

  Future<void> load(String groupId) async {
    value = const GroupAsyncState(loading: true);
    try {
      final res = await repository.listJoinRequests(groupId);
      value = GroupAsyncState(data: res.items);
    } on GroupException catch (e) {
      value = GroupAsyncState(failure: e.failure);
    }
  }

  Future<bool> approve(String groupId, String requestId) async {
    try {
      await repository.approveJoinRequest(requestId);
      await load(groupId);
      return true;
    } on GroupException catch (e) {
      value = GroupAsyncState(data: value.data, failure: e.failure);
      return false;
    }
  }

  Future<bool> reject(String groupId, String requestId) async {
    try {
      await repository.rejectJoinRequest(requestId);
      await load(groupId);
      return true;
    } on GroupException catch (e) {
      value = GroupAsyncState(data: value.data, failure: e.failure);
      return false;
    }
  }
}

class GroupBansController
    extends ValueNotifier<GroupAsyncState<List<GroupBanResponse>>> {
  final GroupRepository repository;
  GroupBansController(this.repository) : super(const GroupAsyncState());

  Future<void> load(String groupId) async {
    value = const GroupAsyncState(loading: true);
    try {
      final res = await repository.listBans(groupId);
      value = GroupAsyncState(data: res.items);
    } on GroupException catch (e) {
      value = GroupAsyncState(failure: e.failure);
    }
  }

  Future<bool> ban(String groupId, String userId, {String? reason}) async {
    try {
      await repository.banMember(
        groupId,
        userId,
        BanMemberRequest(reason: reason),
      );
      await load(groupId);
      return true;
    } on GroupException catch (e) {
      value = GroupAsyncState(data: value.data, failure: e.failure);
      return false;
    }
  }

  Future<bool> unban(String groupId, String userId) async {
    try {
      await repository.unbanUser(groupId, userId);
      await load(groupId);
      return true;
    } on GroupException catch (e) {
      value = GroupAsyncState(data: value.data, failure: e.failure);
      return false;
    }
  }
}

class GroupLifecycleController extends ValueNotifier<GroupAsyncState<void>> {
  final GroupRepository repository;
  GroupLifecycleController(this.repository) : super(const GroupAsyncState());

  Future<bool> archive(String groupId) async {
    value = const GroupAsyncState(loading: true);
    try {
      await repository.archiveGroup(groupId);
      value = const GroupAsyncState();
      return true;
    } on GroupException catch (e) {
      value = GroupAsyncState(failure: e.failure);
      return false;
    }
  }

  Future<bool> restore(String groupId) async {
    value = const GroupAsyncState(loading: true);
    try {
      await repository.restoreGroup(groupId);
      value = const GroupAsyncState();
      return true;
    } on GroupException catch (e) {
      value = GroupAsyncState(failure: e.failure);
      return false;
    }
  }

  Future<bool> delete(String groupId) async {
    value = const GroupAsyncState(loading: true);
    try {
      await repository.deleteGroup(groupId);
      value = const GroupAsyncState();
      return true;
    } on GroupException catch (e) {
      value = GroupAsyncState(failure: e.failure);
      return false;
    }
  }
}
