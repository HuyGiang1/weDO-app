import 'package:flutter/foundation.dart';

import '../data/group_failure.dart';
import '../data/group_repository.dart';
import '../data/models/group_models.dart';

class GroupActivityLogState {
  final bool loading, loadingMore, hasNext;
  final int page;
  final List<GroupActivityLog> activities;
  final GroupFailure? failure;
  const GroupActivityLogState({
    this.loading = false,
    this.loadingMore = false,
    this.hasNext = false,
    this.page = 0,
    this.activities = const [],
    this.failure,
  });
}

class GroupActivityLogController extends ValueNotifier<GroupActivityLogState> {
  final GroupRepository repository;
  GroupActivityLogController(this.repository)
    : super(const GroupActivityLogState());

  Future<void> load(String groupId) async {
    value = const GroupActivityLogState(loading: true);
    try {
      final page = await repository.getActivityLogs(groupId);
      value = GroupActivityLogState(
        activities: page.items,
        page: page.page,
        hasNext: page.hasNext,
      );
    } on GroupException catch (error) {
      value = GroupActivityLogState(failure: error.failure);
    }
  }

  Future<void> loadMore(String groupId) async {
    final old = value;
    if (old.loading || old.loadingMore || !old.hasNext) return;
    value = GroupActivityLogState(
      activities: old.activities,
      page: old.page,
      hasNext: old.hasNext,
      loadingMore: true,
    );
    try {
      final page = await repository.getActivityLogs(groupId, page: old.page + 1);
      value = GroupActivityLogState(
        activities: [...old.activities, ...page.items],
        page: page.page,
        hasNext: page.hasNext,
      );
    } on GroupException catch (error) {
      value = GroupActivityLogState(
        activities: old.activities,
        page: old.page,
        hasNext: old.hasNext,
        failure: error.failure,
      );
    }
  }
}
