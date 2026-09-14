import 'package:flutter/foundation.dart';

import '../data/group_failure.dart';
import '../data/group_repository.dart';
import '../data/models/group_models.dart';

class GroupAsyncState<T> {
  final bool loading;
  final T? data;
  final GroupFailure? failure;
  const GroupAsyncState({this.loading = false, this.data, this.failure});
}

class EditGroupController extends ValueNotifier<GroupAsyncState<GroupDetail>> {
  final GroupRepository repository;
  EditGroupController(this.repository) : super(const GroupAsyncState());
  Future<void> load(String id) async {
    value = const GroupAsyncState(loading: true);
    try {
      value = GroupAsyncState(data: await repository.getGroup(id));
    } on GroupException catch (e) {
      value = GroupAsyncState(failure: e.failure);
    }
  }

  Future<GroupDetail?> save(String id, UpdateGroupRequest request) async {
    value = GroupAsyncState(loading: true, data: value.data);
    try {
      final result = await repository.updateGroup(id, request);
      value = GroupAsyncState(data: result);
      return result;
    } on GroupException catch (e) {
      value = GroupAsyncState(data: value.data, failure: e.failure);
      return null;
    }
  }
}

class GroupMembersController
    extends ValueNotifier<GroupAsyncState<List<GroupMember>>> {
  final GroupRepository repository;
  GroupMembersController(this.repository) : super(const GroupAsyncState());
  Future<void> load(String id) async {
    value = const GroupAsyncState(loading: true);
    try {
      value = GroupAsyncState(data: await repository.getMembers(id));
    } on GroupException catch (e) {
      value = GroupAsyncState(failure: e.failure);
    }
  }
}

class MemberManagementData {
  final GroupDetail group;
  final GroupMember member;
  const MemberManagementData(this.group, this.member);
}

class MemberManagementController
    extends ValueNotifier<GroupAsyncState<MemberManagementData>> {
  final GroupRepository repository;
  MemberManagementController(this.repository) : super(const GroupAsyncState());
  Future<void> load(String groupId, String userId) async {
    value = const GroupAsyncState(loading: true);
    try {
      value = GroupAsyncState(
        data: MemberManagementData(
          await repository.getGroup(groupId),
          await repository.getMember(groupId, userId),
        ),
      );
    } on GroupException catch (e) {
      value = GroupAsyncState(failure: e.failure);
    }
  }

  Future<bool> promote(String groupId, String userId) =>
      _replace(groupId, userId, repository.promoteAdmin);
  Future<bool> demote(String groupId, String userId) =>
      _replace(groupId, userId, repository.demoteAdmin);
  Future<bool> _replace(
    String id,
    String user,
    Future<GroupMember> Function(String, String) action,
  ) async {
    final old = value.data;
    if (old == null) return false;
    try {
      value = GroupAsyncState(
        data: MemberManagementData(old.group, await action(id, user)),
      );
      return true;
    } on GroupException catch (e) {
      value = GroupAsyncState(data: old, failure: e.failure);
      return false;
    }
  }

  Future<bool> kick(String id, String user) async {
    final old = value.data;
    try {
      await repository.kickMember(id, user);
      return true;
    } on GroupException catch (e) {
      value = GroupAsyncState(data: old, failure: e.failure);
      return false;
    }
  }
}

class GroupPermissionsData {
  final GroupDetail group;
  final GroupSettings settings;
  const GroupPermissionsData(this.group, this.settings);
}

class GroupPermissionsController
    extends ValueNotifier<GroupAsyncState<GroupPermissionsData>> {
  final GroupRepository repository;
  GroupPermissionsController(this.repository) : super(const GroupAsyncState());
  Future<void> load(String id) async {
    value = const GroupAsyncState(loading: true);
    try {
      value = GroupAsyncState(
        data: GroupPermissionsData(
          await repository.getGroup(id),
          await repository.getSettings(id),
        ),
      );
    } on GroupException catch (e) {
      value = GroupAsyncState(failure: e.failure);
    }
  }

  Future<bool> save(String id, UpdateGroupSettingsRequest request) async {
    final old = value.data;
    if (old == null) return false;
    try {
      value = GroupAsyncState(
        data: GroupPermissionsData(
          old.group,
          await repository.updateSettings(id, request),
        ),
      );
      return true;
    } on GroupException catch (e) {
      value = GroupAsyncState(data: old, failure: e.failure);
      return false;
    }
  }
}

class GroupAdminData {
  final GroupDetail group;
  final List<GroupMember> members;
  const GroupAdminData(this.group, this.members);
}

class GroupAdminController
    extends ValueNotifier<GroupAsyncState<GroupAdminData>> {
  final GroupRepository repository;
  GroupAdminController(this.repository) : super(const GroupAsyncState());
  Future<void> load(String id) async {
    value = const GroupAsyncState(loading: true);
    try {
      value = GroupAsyncState(
        data: GroupAdminData(
          await repository.getGroup(id),
          await repository.getMembers(id),
        ),
      );
    } on GroupException catch (e) {
      value = GroupAsyncState(failure: e.failure);
    }
  }

  Future<bool> _change(
    String id,
    String user,
    Future<GroupMember> Function(String, String) action,
  ) async {
    final old = value.data;
    if (old == null) return false;
    try {
      final changed = await action(id, user);
      value = GroupAsyncState(
        data: GroupAdminData(old.group, [
          for (final m in old.members)
            if (m.userId == user) changed else m,
        ]),
      );
      return true;
    } on GroupException catch (e) {
      value = GroupAsyncState(data: old, failure: e.failure);
      return false;
    }
  }

  Future<bool> promote(String id, String user) =>
      _change(id, user, repository.promoteAdmin);
  Future<bool> demote(String id, String user) =>
      _change(id, user, repository.demoteAdmin);
}

class TransferOwnershipController
    extends ValueNotifier<GroupAsyncState<GroupAdminData>> {
  final GroupRepository repository;
  TransferOwnershipController(this.repository) : super(const GroupAsyncState());
  Future<void> load(String id) async {
    value = const GroupAsyncState(loading: true);
    try {
      value = GroupAsyncState(
        data: GroupAdminData(
          await repository.getGroup(id),
          await repository.getMembers(id),
        ),
      );
    } on GroupException catch (e) {
      value = GroupAsyncState(failure: e.failure);
    }
  }

  Future<GroupDetail?> transfer(String id, String user) async {
    final old = value.data;
    if (old == null) return null;
    try {
      final detail = await repository.transferOwnership(
        id,
        TransferOwnershipRequest(user),
      );
      value = GroupAsyncState(data: GroupAdminData(detail, old.members));
      return detail;
    } on GroupException catch (e) {
      value = GroupAsyncState(data: old, failure: e.failure);
      return null;
    }
  }
}
