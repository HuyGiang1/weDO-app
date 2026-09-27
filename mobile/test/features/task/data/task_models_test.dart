import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/task/data/task_models.dart';

void main() {
  test('ActivityTask parses assignments, due date, and status history', () {
    final task = ActivityTask.fromJson({
      'id': 'task-1',
      'activityId': 'activity-1',
      'createdBy': 'user-1',
      'title': 'Bring drinks',
      'description': null,
      'status': 'IN_PROGRESS',
      'dueAt': '2026-10-01T10:00:00Z',
      'assigneeUserIds': ['user-2'],
      'permissions': {
        'canEdit': true,
        'canManageAssignees': true,
        'canClaim': false,
        'canChangeStatus': true,
        'canDelete': true,
      },
      'statusHistory': [
        {
          'fromStatus': 'TODO',
          'toStatus': 'IN_PROGRESS',
          'changedBy': 'user-2',
          'createdAt': '2026-09-30T10:00:00Z',
        },
      ],
    });
    expect(task.status, ActivityTaskStatus.inProgress);
    expect(task.assigneeUserIds, ['user-2']);
    expect(task.statusHistory.single.toStatus, ActivityTaskStatus.inProgress);
    expect(task.permissions.canEdit, isTrue);
    expect(task.permissions.canManageAssignees, isTrue);
    expect(task.permissions.canClaim, isFalse);
    expect(task.permissions.canChangeStatus, isTrue);
    expect(task.permissions.canDelete, isTrue);
  });

  test('ActivityTask defaults absent permission flags to unavailable', () {
    final permissions = ActivityTaskPermissions.fromJson(null);
    expect(permissions.canEdit, isFalse);
    expect(permissions.canManageAssignees, isFalse);
    expect(permissions.canClaim, isFalse);
    expect(permissions.canChangeStatus, isFalse);
    expect(permissions.canDelete, isFalse);
  });

  test(
    'ActivityTask accepts the initial history record without a prior status',
    () {
      final history = ActivityTaskHistory.fromJson({
        'fromStatus': null,
        'toStatus': 'TODO',
        'changedBy': 'user-1',
        'createdAt': '2026-09-30T10:00:00Z',
      });

      expect(history.fromStatus, isNull);
      expect(history.toStatus, ActivityTaskStatus.todo);
    },
  );

  test('ActivityTaskDraft only serializes server-supported fields', () {
    final data = ActivityTaskDraft(
      title: 'Bring drinks',
      assigneeUserIds: const ['user-2'],
    ).toJson();
    expect(
      data.keys,
      containsAll(['title', 'description', 'assigneeUserIds', 'dueAt']),
    );
    expect(data['assigneeUserIds'], ['user-2']);
    expect(data['dueAt'], isNull);
  });

  test('ActivityTaskDraft serializes a local due time as a UTC Instant', () {
    final dueAt = DateTime(2030, 5, 1, 9, 30);
    final data = ActivityTaskDraft(
      title: 'Bring drinks',
      assigneeUserIds: const ['user-2', 'user-3'],
      dueAt: dueAt,
    ).toJson();

    expect(data['dueAt'], dueAt.toUtc().toIso8601String());
    expect((data['dueAt'] as String).endsWith('Z'), isTrue);
    expect(data['assigneeUserIds'], ['user-2', 'user-3']);
  });

  test('ActivityTaskStatus uses the canonical Task wire values', () {
    expect(ActivityTaskStatus.todo.wire, 'TODO');
    expect(ActivityTaskStatus.inProgress.wire, 'IN_PROGRESS');
    expect(ActivityTaskStatus.done.wire, 'DONE');
    expect(ActivityTaskStatusWire.parse('DONE'), ActivityTaskStatus.done);
  });
}
