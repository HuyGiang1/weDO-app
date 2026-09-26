import 'package:flutter/foundation.dart';

import '../data/activity_failure.dart';
import '../data/activity_models.dart';
import '../data/activity_repository.dart';

enum ActivityLoadPhase { loading, data, empty, error }

class ActivityListState {
  final ActivityLoadPhase phase;
  final List<ActivitySummary> items;
  final ActivityFailure? failure;
  const ActivityListState(this.phase, {this.items = const [], this.failure});
}

class ActivityListController extends ValueNotifier<ActivityListState> {
  final ActivityRepository repository;
  ActivityListController(this.repository)
    : super(const ActivityListState(ActivityLoadPhase.loading));
  Future<void> load(String groupId) async {
    value = const ActivityListState(ActivityLoadPhase.loading);
    try {
      final page = await repository.list(groupId);
      value = ActivityListState(
        page.items.isEmpty ? ActivityLoadPhase.empty : ActivityLoadPhase.data,
        items: page.items,
      );
    } on ActivityException catch (e) {
      value = ActivityListState(ActivityLoadPhase.error, failure: e.failure);
    }
  }

  Future<ActivityDetail?> create(String groupId, ActivityDraft draft) async {
    try {
      final detail = await repository.create(groupId, draft);
      await load(groupId);
      return detail;
    } on ActivityException catch (e) {
      value = ActivityListState(
        ActivityLoadPhase.error,
        items: value.items,
        failure: e.failure,
      );
      return null;
    }
  }
}

class ActivityDetailState {
  final bool loading;
  final ActivityDetail? detail;
  final List<ActivityParticipant> participants;
  final ActivityFailure? failure;
  const ActivityDetailState({
    this.loading = false,
    this.detail,
    this.participants = const [],
    this.failure,
  });
}

class ActivityDetailController extends ValueNotifier<ActivityDetailState> {
  final ActivityRepository repository;
  ActivityDetailController(this.repository)
    : super(const ActivityDetailState());
  Future<void> load(String id) async {
    value = const ActivityDetailState(loading: true);
    try {
      final detail = await repository.detail(id);
      final participants = await repository.participants(id);
      value = ActivityDetailState(detail: detail, participants: participants);
    } on ActivityException catch (e) {
      value = ActivityDetailState(failure: e.failure);
    }
  }

  Future<bool> _mutate(String id, Future<ActivityDetail> Function() op) async {
    try {
      final detail = await op();
      final participants = await repository.participants(id);
      value = ActivityDetailState(detail: detail, participants: participants);
      return true;
    } on ActivityException catch (e) {
      value = ActivityDetailState(
        detail: value.detail,
        participants: value.participants,
        failure: e.failure,
      );
      return false;
    }
  }

  Future<bool> confirm(String id) => _mutate(id, () => repository.confirm(id));
  Future<bool> cancel(String id, {String? reason}) =>
      _mutate(id, () => repository.cancel(id, reason: reason));
  Future<bool> complete(String id) =>
      _mutate(id, () => repository.complete(id));
  Future<bool> update(String id, Map<String, dynamic> request) =>
      _mutate(id, () => repository.update(id, request));
  Future<bool> rsvp(String id, ActivityRsvpStatus status) async {
    if (!status.clientSelectable) return false;
    try {
      await repository.rsvp(id, status);
      await load(id);
      return value.detail != null;
    } on ActivityException catch (e) {
      value = ActivityDetailState(
        detail: value.detail,
        participants: value.participants,
        failure: e.failure,
      );
      return false;
    }
  }
}
