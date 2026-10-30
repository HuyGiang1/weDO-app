import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/groups/data/models/group_models.dart';
import 'package:mobile/features/task/data/task_api.dart';
import 'package:mobile/features/task/data/task_models.dart';
import 'package:mobile/features/task/data/task_repository.dart';
import 'package:mobile/features/task/presentation/screens/task_screens.dart';

GroupMember _member(String id) => GroupMember(
  userId: id,
  username: id,
  displayName: id,
  role: GroupRole.member,
  joinedAt: DateTime.utc(2030),
);

class _Repository extends TaskRepository {
  bool canChangeStatus;
  int updates = 0;
  _Repository() : canChangeStatus = false, super(TaskApi(Dio()));
  @override
  Future<List<GroupMember>> eligibleAssignees(String activityId) async => [
    _member('Participant'),
  ];
  @override
  Future<ActivityTask> get(String id) async => ActivityTask(
    id: id,
    activityId: 'activity',
    createdBy: 'owner',
    title: 'Task',
    description: null,
    status: ActivityTaskStatus.todo,
    dueAt: null,
    assigneeUserIds: const ['Participant'],
    statusHistory: const [],
    permissions: ActivityTaskPermissions(
      canEdit: true,
      canManageAssignees: true,
      canClaim: false,
      canChangeStatus: canChangeStatus,
      canDelete: true,
    ),
  );
  @override
  Future<ActivityTask> updateStatus(
    String id,
    ActivityTaskStatus status,
  ) async {
    updates++;
    return get(id);
  }
}

void main() {
  testWidgets(
    'creation picker uses Activity candidates, not all group members',
    (tester) async {
      final repo = _Repository();
      await tester.pumpWidget(
        MaterialApp(
          home: CreateTaskScreen(
            activityId: 'activity',
            repository: repo,
            loadMembers: () async => [
              _member('Participant'),
              _member('Nonparticipant'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chưa phân công'));
      await tester.pumpAndSettle();
      expect(find.text('Participant'), findsOneWidget);
      expect(find.text('Nonparticipant'), findsNothing);
    },
  );

  testWidgets(
    'server permission disables non-assignee status but retains management',
    (tester) async {
      final repo = _Repository();
      await tester.pumpWidget(
        MaterialApp(
          home: TaskDetailScreen(
            taskId: 'task',
            repository: repo,
            loadMembers: () async => [
              _member('Participant'),
              _member('Nonparticipant'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cần làm'));
      await tester.pumpAndSettle();
      expect(find.text('Hoàn thành'), findsNothing);
      expect(repo.updates, 0);
      expect(find.text('Xóa công việc'), findsOneWidget);
      repo.canChangeStatus = true;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          home: TaskDetailScreen(
            taskId: 'task',
            repository: repo,
            loadMembers: () async => [_member('Participant')],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cần làm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hoàn thành'));
      await tester.pumpAndSettle();
      expect(repo.updates, 1);
    },
  );
}
