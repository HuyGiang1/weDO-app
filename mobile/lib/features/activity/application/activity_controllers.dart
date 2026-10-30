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
  int _generation = 0;
  bool _disposed = false;
  ActivityListController(this.repository)
    : super(const ActivityListState(ActivityLoadPhase.loading));
  Future<void> load(String groupId) => _load(groupId, false);
  Future<void> resync(String groupId) => _load(groupId, true);
  Future<void> _load(String groupId, bool silent) async {
    if (_disposed) return;
    final generation = ++_generation;
    if (!silent) value = const ActivityListState(ActivityLoadPhase.loading);
    try {
      final page = await repository.list(groupId);
      if (_disposed || generation != _generation) return;
      value = ActivityListState(
        page.items.isEmpty ? ActivityLoadPhase.empty : ActivityLoadPhase.data,
        items: page.items,
      );
    } on ActivityException catch (e) {
      if (_disposed || generation != _generation) return;
      value = ActivityListState(ActivityLoadPhase.error, failure: e.failure);
    }
  }

  @override
  void dispose() { _disposed = true; _generation++; super.dispose(); }

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
  int _generation = 0;
  bool _disposed = false;
  ActivityDetailController(this.repository)
    : super(const ActivityDetailState());
  Future<void> load(String id) => _load(id, false);
  Future<void> resync(String id) => _load(id, true);
  Future<void> _load(String id, bool silent) async {
    if (_disposed) return;
    final generation = ++_generation;
    final previous = value.detail?.id == id ? value : const ActivityDetailState();
    if (!silent || previous.detail == null) {
      value = ActivityDetailState(loading: true, detail: previous.detail, participants: previous.participants);
    }
    try {
      final detail = await repository.detail(id);
      final participants = await repository.participants(id);
      if (_disposed || generation != _generation) return;
      value = ActivityDetailState(detail: detail, participants: participants);
    } on ActivityException catch (e) {
      if (_disposed || generation != _generation) return;
      final retain = e.failure.type == ActivityFailureType.network;
      value = ActivityDetailState(
        detail: retain ? previous.detail : null,
        participants: retain ? previous.participants : const [],
        failure: retain && previous.failure != null && _accessDenied(previous.failure!)
            ? previous.failure : e.failure,
      );
    } catch (error, stack) {
      if (!_disposed && generation == _generation) {
        value = const ActivityDetailState(failure: ActivityFailure(ActivityFailureType.unknown));
      }
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack,
          library: 'Activity', context: ErrorDescription('while refetching Activity detail')));
    }
  }

  void denyAccess() {
    if (_disposed) return;
    _generation++;
    value = const ActivityDetailState(failure: ActivityFailure(ActivityFailureType.permission));
  }

  @override
  void dispose() { _disposed = true; _generation++; super.dispose(); }

  Future<bool> _mutate(String id, Future<ActivityDetail> Function() op) async {
    if (_disposed) return false;
    final generation = ++_generation;
    try {
      final detail = await op();
      final participants = await repository.participants(id);
      if (_disposed || generation != _generation) return true;
      value = ActivityDetailState(detail: detail, participants: participants);
      return true;
    } on ActivityException catch (e) {
      if (_disposed || generation != _generation) return false;
      if (_accessDenied(e.failure)) { denyAccess(); return false; }
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
    if (_disposed || !status.clientSelectable) return false;
    final generation = ++_generation;
    try {
      await repository.rsvp(id, status);
      if (_disposed || generation != _generation) return false;
      await load(id);
      if (_disposed) return false;
      return value.detail != null;
    } on ActivityException catch (e) {
      if (_disposed || generation != _generation) return false;
      if (_accessDenied(e.failure)) { denyAccess(); return false; }
      value = ActivityDetailState(
        detail: value.detail,
        participants: value.participants,
        failure: e.failure,
      );
      return false;
    }
  }

  bool _accessDenied(ActivityFailure failure) =>
      failure.type == ActivityFailureType.permission ||
      failure.type == ActivityFailureType.unauthorized ||
      failure.type == ActivityFailureType.notFound;
}
