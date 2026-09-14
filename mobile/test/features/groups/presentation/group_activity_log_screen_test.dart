import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/paged_response.dart';
import 'package:mobile/features/groups/application/group_activity_log_controller.dart';
import 'package:mobile/features/groups/data/group_api.dart';
import 'package:mobile/features/groups/data/group_failure.dart';
import 'package:mobile/features/groups/data/group_repository.dart';
import 'package:mobile/features/groups/data/models/group_models.dart';
import 'package:mobile/features/groups/presentation/screens/group_activity_log_screen.dart';

void main() {
  test('controller loads page zero, preserves backend order, and loads more', () async {
    final repo = _ActivityRepo(hasNext: true);
    final controller = GroupActivityLogController(repo);
    await controller.load('group-id');
    expect(repo.requests, [(0, 30)]);
    expect(controller.value.activities.map((item) => item.id), ['one']);
    await controller.loadMore('group-id');
    expect(repo.requests, [(0, 30), (1, 30)]);
    expect(controller.value.activities.map((item) => item.id), ['one', 'two']);
  });

  test('controller exposes typed error and empty state without fabricated activities', () async {
    final failed = GroupActivityLogController(_ActivityRepo(fail: true));
    await failed.load('group-id');
    expect(failed.value.failure!.type, GroupFailureType.groupNotFound);
    final empty = GroupActivityLogController(_ActivityRepo(empty: true));
    await empty.load('group-id');
    expect(empty.value.activities, isEmpty);
  });

  testWidgets('Stitch activity screen renders timeline cards with safe action text', (tester) async {
    final activities = [
      for (final action in _actions) _activity(action),
    ];
    await tester.pumpWidget(MaterialApp(
      home: GroupActivityLogScreen(
        groupId: 'group-id',
        controller: GroupActivityLogController(_ActivityRepo(activities: activities)),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Activity Log'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);
    for (final text in _messages) {
      expect(find.text(text), findsOneWidget);
    }
    expect(find.textContaining('actor-uuid'), findsNothing);
    expect(find.textContaining('Alex'), findsNothing);
  });

  testWidgets('screen renders restrained empty and retryable error states', (tester) async {
    await tester.pumpWidget(MaterialApp(home: GroupActivityLogScreen(
      key: const ValueKey('empty'),
      groupId: 'group-id', controller: GroupActivityLogController(_ActivityRepo(empty: true)),
    )));
    await tester.pumpAndSettle();
    expect(find.text('No activity yet'), findsOneWidget);
    await tester.pumpWidget(MaterialApp(home: GroupActivityLogScreen(
      key: const ValueKey('error'),
      groupId: 'group-id', controller: GroupActivityLogController(_ActivityRepo(fail: true)),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
  });

  test('timestamp formatter is deterministic for recent, yesterday, and older entries', () {
    final now = DateTime(2026, 10, 25, 18, 30);
    expect(formatActivityTimestamp(now.subtract(const Duration(hours: 2)), now: now), '2 hours ago');
    expect(formatActivityTimestamp(DateTime(2026, 10, 24, 16, 30), now: now), 'Yesterday at 4:30 PM');
    expect(formatActivityTimestamp(DateTime(2023, 10, 24), now: now), 'Oct 24, 2023');
  });
}

const _actions = [
  'GROUP_CREATED', 'GROUP_UPDATED', 'GROUP_SETTINGS_UPDATED', 'GROUP_ADMIN_PROMOTED',
  'GROUP_ADMIN_DEMOTED', 'GROUP_MEMBER_KICKED', 'GROUP_MEMBER_LEFT', 'GROUP_OWNERSHIP_TRANSFERRED',
];
const _messages = [
  'Group created', 'Group information updated', 'Group settings updated', 'A member was promoted to Admin',
  'An Admin was changed to Member', 'A member was removed from the group', 'A member left the group', 'Group ownership was transferred',
];

GroupActivityLog _activity(String action, {String id = 'one'}) => GroupActivityLog(
  id: id, action: action, actorUserId: 'actor-uuid', targetUserId: 'target-uuid',
  createdAt: DateTime.now().subtract(const Duration(hours: 2)),
);

class _ActivityRepo extends GroupRepository {
  _ActivityRepo({this.activities = const [], this.empty = false, this.fail = false, this.hasNext = false}) : super(api: GroupApi(Dio()));
  final List<GroupActivityLog> activities;
  final bool empty, fail, hasNext;
  final List<(int, int)> requests = [];
  @override
  Future<PagedResponse<GroupActivityLog>> getActivityLogs(String id, {int page = 0, int size = 30}) async {
    requests.add((page, size));
    if (fail) throw const GroupException(GroupFailure(GroupFailureType.groupNotFound));
    final items = empty ? <GroupActivityLog>[] : activities.isEmpty
        ? [_activity(page == 0 ? 'GROUP_CREATED' : 'GROUP_UPDATED', id: page == 0 ? 'one' : 'two')]
        : activities;
    return PagedResponse(items: items, page: page, size: size, totalElements: items.length, totalPages: hasNext ? 2 : 1, hasNext: hasNext && page == 0);
  }
}
