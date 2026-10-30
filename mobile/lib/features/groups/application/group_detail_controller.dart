import 'package:flutter/foundation.dart';

import '../data/group_failure.dart';
import '../data/group_repository.dart';
import '../data/models/group_models.dart';

class GroupDetailState {
  final bool loading;
  final GroupDetail? detail;
  final int? memberCount;
  final int? pendingJoinRequestCount;
  final GroupMember? owner;
  final List<GroupMember> members;
  final GroupSettings? settings;
  final GroupFailure? failure, memberCountFailure;
  const GroupDetailState({
    this.loading = false,
    this.detail,
    this.memberCount,
    this.pendingJoinRequestCount,
    this.owner,
    this.members = const [],
    this.settings,
    this.failure,
    this.memberCountFailure,
  });
}

class GroupDetailController extends ValueNotifier<GroupDetailState> {
  final GroupRepository repository;
  final bool readSettings;
  int _generation = 0;
  bool _disposed = false;
  GroupDetailController(this.repository, {this.readSettings = false})
    : super(const GroupDetailState());
  Future<void> load(String id) => _load(id, false);
  Future<void> resync(String id) => _load(id, true);
  Future<void> _load(String id, bool silent) async {
    if (_disposed) return;
    final generation = ++_generation;
    if (!silent) value = const GroupDetailState(loading: true);
    try {
      final detail = await repository.getGroup(id);
      if (_disposed || generation != _generation) return;
      if (!silent) value = GroupDetailState(detail: detail);
      try {
        final members = await repository.getMembers(id);
        if (_disposed || generation != _generation) return;
        final owners = members.where((m) => m.userId == detail.ownerUserId);
        value = GroupDetailState(
          detail: detail,
          memberCount: members.length,
          owner: owners.firstOrNull,
          members: List.unmodifiable(members),
        );
        if (readSettings) {
          try {
            final settings = await repository.getSettings(id);
            if (_disposed || generation != _generation) return;
            value = GroupDetailState(
              detail: detail,
              memberCount: members.length,
              owner: owners.firstOrNull,
              members: List.unmodifiable(members),
              settings: settings,
            );
          } on GroupException {
            // Optional capability metadata unavailable: do not infer member edit rights.
          }
          if (detail.callerRole == GroupRole.owner ||
              detail.callerRole == GroupRole.admin) {
            try {
              // This existing endpoint is PENDING-only; use its total, not page length.
              final pending = await repository.listJoinRequests(id, size: 1);
              if (_disposed || generation != _generation) return;
              value = GroupDetailState(
                detail: detail,
                memberCount: members.length,
                owner: owners.firstOrNull,
                members: List.unmodifiable(members),
                settings: value.settings,
                pendingJoinRequestCount: pending.totalElements,
              );
            } on GroupException {
              // Unavailable metadata is unknown, never a fabricated zero.
            }
          }
        }
      } on GroupException catch (e) {
        if (_disposed || generation != _generation) return;
        value = GroupDetailState(detail: detail, memberCountFailure: e.failure);
      }
    } on GroupException catch (e) {
      if (_disposed || generation != _generation) return;
      value = GroupDetailState(failure: e.failure);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
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
        pendingJoinRequestCount: old.pendingJoinRequestCount,
        owner: old.owner,
        members: old.members,
        settings: old.settings,
        failure: e.failure,
      );
      return false;
    }
  }
}
