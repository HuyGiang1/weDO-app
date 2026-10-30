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
  int _generation = 0;
  bool _disposed = false;
  GroupsController(this.repository)
    : super(const GroupsState(GroupsPhase.loading));
  Future<void> load() => _load(false);
  Future<void> resync() => _load(true);
  Future<void> _load(bool silent) async {
    if (_disposed) return;
    final generation = ++_generation;
    if (!silent) value = GroupsState(GroupsPhase.loading, groups: value.groups);
    try {
      final page = await repository.listGroups(
        page: 0,
        size: 30,
        status: GroupStatus.active,
      );
      if (_disposed || generation != _generation) return;
      value = GroupsState(
        page.items.isEmpty ? GroupsPhase.empty : GroupsPhase.data,
        groups: page.items,
      );
    } on GroupException catch (e) {
      if (_disposed || generation != _generation) return;
      value = GroupsState(GroupsPhase.error, failure: e.failure);
    }
  }

  Future<void> refresh() => load();
  @override
  void dispose() { _disposed = true; _generation++; super.dispose(); }
}
