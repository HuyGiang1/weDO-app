import 'package:flutter/foundation.dart';

import '../data/group_failure.dart';
import '../data/group_repository.dart';
import '../data/models/group_models.dart';

enum GroupsPhase { loading, data, empty, error }

class GroupsState {
  final GroupsPhase phase;
  final List<GroupSummary> groups;
  final GroupFailure? failure;
  const GroupsState(this.phase, {this.groups = const [], this.failure});
}

class GroupsController extends ValueNotifier<GroupsState> {
  final GroupRepository repository;
  GroupsController(this.repository)
    : super(const GroupsState(GroupsPhase.loading));
  Future<void> load() async {
    value = const GroupsState(GroupsPhase.loading);
    try {
      final page = await repository.listGroups(
        page: 0,
        size: 30,
        status: GroupStatus.active,
      );
      value = GroupsState(
        page.items.isEmpty ? GroupsPhase.empty : GroupsPhase.data,
        groups: page.items,
      );
    } on GroupException catch (e) {
      value = GroupsState(GroupsPhase.error, failure: e.failure);
    }
  }

  Future<void> refresh() => load();
}
