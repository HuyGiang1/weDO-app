import 'package:flutter/foundation.dart';

import '../data/group_failure.dart';
import '../data/group_repository.dart';
import '../data/models/group_models.dart';

class GroupDetailState {
  final bool loading;
  final GroupDetail? detail;
  final int? memberCount;
  final GroupFailure? failure, memberCountFailure;
  const GroupDetailState({
    this.loading = false,
    this.detail,
    this.memberCount,
    this.failure,
    this.memberCountFailure,
  });
}

class GroupDetailController extends ValueNotifier<GroupDetailState> {
  final GroupRepository repository;
  GroupDetailController(this.repository) : super(const GroupDetailState());
  Future<void> load(String id) async {
    value = const GroupDetailState(loading: true);
    try {
      final detail = await repository.getGroup(id);
      value = GroupDetailState(detail: detail);
      try {
        final members = await repository.getMembers(id);
        value = GroupDetailState(detail: detail, memberCount: members.length);
      } on GroupException catch (e) {
        value = GroupDetailState(detail: detail, memberCountFailure: e.failure);
      }
    } on GroupException catch (e) {
      value = GroupDetailState(failure: e.failure);
    }
  }
  Future<bool> leave(String id) async {
    final old = value;
    try {
      await repository.leaveGroup(id);
      return true;
    } on GroupException catch (e) {
      value = GroupDetailState(
        detail: old.detail,
        memberCount: old.memberCount,
        failure: e.failure,
      );
      return false;
    }
  }
}
