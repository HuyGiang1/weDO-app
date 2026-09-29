import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/routes.dart';
import 'package:mobile/features/groups/data/group_api.dart';
import 'package:mobile/features/groups/data/group_repository.dart';
import 'package:mobile/features/expense/presentation/expense_screens.dart';
import 'package:mobile/features/notification/data/notification_models.dart';
import 'package:mobile/features/notification/presentation/notification_target_router.dart';

void main() {
  testWidgets('authoritative activity target opens its detail route', (
    WidgetTester tester,
  ) async {
    final GroupRepository groups = GroupRepository(api: GroupApi(Dio()));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: TextButton(
              key: const Key('open-target'),
              onPressed: () => unawaited(
                NotificationTargetRouter.open(
                  context: context,
                  item: _item(),
                  groupRepository: groups,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
        onGenerateRoute: (RouteSettings settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(body: Text(settings.name ?? 'unknown')),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-target')));
    await tester.pumpAndSettle();

    expect(find.text(AppRoutes.activityDetail), findsOneWidget);
  });

  testWidgets(
    'Poll and Task targets resolve to their embedded Activity detail',
    (WidgetTester tester) async {
      for (final String targetType in <String>['POLL', 'TASK']) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (BuildContext context) => Scaffold(
                body: TextButton(
                  key: const Key('open-target'),
                  onPressed: () => unawaited(
                    NotificationTargetRouter.open(
                      context: context,
                      item: _item(
                        targetType: targetType,
                        targetId: '$targetType-1',
                        route: AppRoutes.activityDetail,
                        params: const <String, dynamic>{
                          'activityId': 'activity-1',
                        },
                      ),
                      groupRepository: GroupRepository(api: GroupApi(Dio())),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
            onGenerateRoute: (RouteSettings settings) =>
                MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) =>
                      Scaffold(body: Text(settings.name ?? 'unknown')),
                ),
          ),
        );

        await tester.tap(find.byKey(const Key('open-target')));
        await tester.pumpAndSettle();
        expect(find.text(AppRoutes.activityDetail), findsOneWidget);
      }
    },
  );

  testWidgets(
    'supported group and finance target routes resolve to real screens',
    (WidgetTester tester) async {
      final GroupRepository groups = GroupRepository(api: GroupApi(Dio()));
      final List<(NotificationItemModel, String)> namedTargets =
          <(NotificationItemModel, String)>[
            (
              _item(
                targetType: 'GROUP',
                targetId: 'group-1',
                route: AppRoutes.groupInfo,
              ),
              AppRoutes.groupInfo,
            ),
            (
              _item(
                targetType: 'GROUP_INVITATION',
                targetId: 'invite-1',
                route: AppRoutes.groupInvitations,
              ),
              AppRoutes.groupInvitations,
            ),
            (
              _item(
                targetType: 'CONVERSATION',
                targetId: 'conversation-1',
                route: AppRoutes.groupChat,
              ),
              AppRoutes.groupChat,
            ),
            (
              _item(
                targetType: 'FUND',
                targetId: 'fund-1',
                route: AppRoutes.groupFund,
              ),
              AppRoutes.groupFund,
            ),
            (
              _item(
                targetType: 'FINANCE',
                targetId: 'group-1',
                route: AppRoutes.groupExpenses,
              ),
              AppRoutes.groupExpenses,
            ),
          ];

      for (final (NotificationItemModel item, String expectedRoute)
          in namedTargets) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (BuildContext context) => Scaffold(
                body: TextButton(
                  key: const Key('open-target'),
                  onPressed: () => unawaited(
                    NotificationTargetRouter.open(
                      context: context,
                      item: item,
                      groupRepository: groups,
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
            onGenerateRoute: (RouteSettings settings) =>
                MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) =>
                      Scaffold(body: Text(settings.name ?? 'unknown')),
                ),
          ),
        );
        await tester.tap(find.byKey(const Key('open-target')));
        await tester.pumpAndSettle();
        expect(find.text(expectedRoute), findsOneWidget);
      }
    },
  );

  testWidgets('Expense and Settlement target IDs open their detail screens', (
    WidgetTester tester,
  ) async {
    final GroupRepository groups = GroupRepository(api: GroupApi(Dio()));
    for (final String targetType in <String>['EXPENSE', 'SETTLEMENT']) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: TextButton(
                key: const Key('open-target'),
                onPressed: () => unawaited(
                  NotificationTargetRouter.open(
                    context: context,
                    item: _item(
                      targetType: targetType,
                      targetId: '$targetType-1',
                      route: '/finance/detail',
                    ),
                    groupRepository: groups,
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open-target')));
      await tester.pumpAndSettle();
      expect(
        find.byType(
          targetType == 'EXPENSE'
              ? ExpenseDetailScreen
              : SettlementDetailScreen,
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets(
    'stale server target remains readable and shows unavailable state',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: TextButton(
                key: const Key('open-stale-target'),
                onPressed: () => unawaited(
                  NotificationTargetRouter.open(
                    context: context,
                    item: _item(actionable: false),
                    groupRepository: null,
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open-stale-target')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
    },
  );
}

NotificationItemModel _item({
  bool actionable = true,
  String targetType = 'ACTIVITY',
  String? targetId = 'activity-1',
  String route = AppRoutes.activityDetail,
  Map<String, dynamic> params = const <String, dynamic>{},
}) => NotificationItemModel(
  notificationId: 'notification-1',
  userId: 'recipient-1',
  category: targetType == 'POLL'
      ? 'POLL'
      : targetType == 'TASK'
      ? 'TASK'
      : 'ACTIVITY',
  eventType: '${targetType}_UPDATED',
  priority: 'NORMAL',
  critical: false,
  title: 'Activity changed',
  body: 'Open the activity',
  group: const NotificationGroupSummaryModel(
    groupId: 'group-1',
    groupName: 'Group',
    groupStatus: 'ACTIVE',
  ),
  target: NotificationTargetModel(
    targetType: targetType,
    targetId: targetId,
    route: route,
    actionable: actionable,
    nonActionableReason: actionable ? null : 'Activity is cancelled',
    params: params,
  ),
  isRead: true,
  createdAt: DateTime.utc(2026, 9, 29),
);
