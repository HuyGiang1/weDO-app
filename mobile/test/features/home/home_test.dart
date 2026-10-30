import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/core/realtime/realtime_binding.dart';
import 'package:mobile/core/realtime/realtime_sync.dart';
import 'package:mobile/features/chat/data/chat_realtime_client.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:mobile/features/expense/data/expense_models.dart';
import 'package:mobile/features/home/application/home_controller.dart';
import 'package:mobile/features/home/data/home_models.dart';
import 'package:mobile/features/home/data/home_repository.dart';
import 'package:mobile/features/home/presentation/home_screen.dart';
import 'package:mobile/features/notification/data/notification_models.dart';

class _Gateway implements HomeGateway {
  Future<HomeResponse> Function()? next;
  int calls = 0;

  @override
  Future<HomeResponse> load() {
    calls++;
    return next!();
  }
}

HomeResponse _response() => HomeResponse(
  [const HomeGroup('group-1', 'Study group', null)],
  [
    HomeActivity(
      'activity-1',
      'group-1',
      'Study group',
      'Project meeting',
      DateTime.utc(2026, 11, 1),
    ),
  ],
  HomeFinance(ExpenseMoney.fromJson('25.00'), ExpenseMoney.fromJson('10.00'), [
    HomeGroupBalance(
      'group-1',
      'Study group',
      ExpenseMoney.fromJson('25.00'),
      ExpenseMoney.zero,
    ),
  ]),
  [
    const HomeAction(
      HomeActionType.rsvpRequired,
      'activity-1',
      'group-1',
      'activity-1',
      'Project meeting',
      null,
    ),
    const HomeAction(
      HomeActionType.pollVoteRequired,
      'poll-1',
      'group-1',
      'activity-1',
      'Where?',
      null,
    ),
    const HomeAction(
      HomeActionType.taskDue,
      'task-1',
      'group-1',
      'activity-1',
      'Bring notes',
      null,
    ),
    const HomeAction(
      HomeActionType.settlementConfirmation,
      'settlement-1',
      'group-1',
      null,
      'Study group',
      null,
    ),
  ],
  [
    NotificationItemModel(
      notificationId: 'update-1',
      userId: 'viewer-1',
      category: 'GROUP',
      eventType: 'GROUP_UPDATED',
      priority: 'NORMAL',
      critical: false,
      title: 'Group changed',
      body: 'New group details',
      group: const NotificationGroupSummaryModel(
        groupId: 'group-1',
        groupName: 'Study group',
      ),
      target: const NotificationTargetModel(
        targetType: 'GROUP',
        targetId: 'group-1',
        route: '/groups/info',
        actionable: true,
      ),
      isRead: false,
      createdAt: DateTime.utc(2026, 10, 1),
    ),
  ],
);

Widget _screen(
  HomeController controller, {
  ValueChanged<String>? group,
  ValueChanged<String>? activity,
  ValueChanged<String>? balance,
  ValueChanged<HomeAction>? action,
  ValueChanged<NotificationItemModel>? update,
}) => MaterialApp(
  home: HomeScreen(
    controller: controller,
    onOpenGroup: group ?? (_) {},
    onOpenActivity: activity ?? (_) {},
    onOpenBalance: balance ?? (_) {},
    onOpenAction: action ?? (_) {},
    onOpenUpdate: update ?? (_) {},
    onGroups: () {},
    onChat: () {},
    onCalendar: () {},
    onProfile: () {},
  ),
);

Future<void> _toggleSection(WidgetTester tester, String title) async {
  await tester.scrollUntilVisible(find.text(title), 200,
    scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down));
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

void main() {
  for (final eventType in ['GROUP_MEMBERSHIP_CHANGED','HOME_ACCESS_CHANGED']) { testWidgets('membership invalidation clears protected Home cache offline $eventType', (tester) async {
    final gateway = _Gateway()..next = () async => _response();
    final controller = HomeController(gateway);
    final sync = RealtimeSync(const NoopChatRealtimeClient());
    await tester.pumpWidget(RealtimeHost(sync:sync,child:_screen(controller)));
    await tester.pumpAndSettle();expect(controller.value,isNotNull);
    gateway.next=() async => throw const ApiException(transportFailure:ApiTransportFailure.network);
    sync.accept({'type':'DOMAIN_CHANGED','eventId':'membership','eventType':eventType,'scope':'user:me','aggregateId':'me'});
    await tester.pump(const Duration(milliseconds:100));await tester.pumpAndSettle();expect(controller.value,isNull);
    await tester.pumpWidget(const SizedBox());await tester.runAsync(sync.dispose);
  });
  }

  test('Home DTO parses all sections and preserves decimal amounts', () {
    final data = HomeResponse.fromJson({
      'recentGroups': [
        {'id': 'g', 'name': 'Group', 'avatarStorageKey': null},
      ],
      'upcomingActivities': [
        {
          'id': 'a',
          'groupId': 'g',
          'groupName': 'Group',
          'title': 'Meet',
          'startAt': '2026-11-01T00:00:00Z',
        },
      ],
      'financeSummary': {
        'totalOwedByMe': '1.25',
        'totalOwedToMe': '2.50',
        'groups': [],
      },
      'actionsRequired': [
        {
          'type': 'POLL_VOTE_REQUIRED',
          'targetId': 'p',
          'groupId': 'g',
          'activityId': 'a',
          'title': 'Vote',
          'dueAt': null,
        },
      ],
      'recentUpdates': [
        {
          'id': 'update-1',
          'category': 'GROUP',
          'priority': 'NORMAL',
          'critical': false,
          'title': 'Group changed',
          'body': 'New group details',
          'target': {
            'targetType': 'GROUP',
            'targetId': 'g',
            'route': '/groups/info',
            'actionable': true,
          },
          'read': false,
          'createdAt': '2026-10-01T00:00:00Z',
        },
      ],
    });
    expect(data.recentGroups.single.id, 'g');
    expect(data.upcomingActivities.single.id, 'a');
    expect(data.financeSummary.owedByMe.decimal, '1.25');
    expect(data.financeSummary.owedToMe.decimal, '2.50');
    expect(data.actionsRequired.single.type, HomeActionType.pollVoteRequired);
    expect(data.recentUpdates.single.notificationId, 'update-1');
  });

  test('Home API maps the canonical endpoint response', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.path, '/api/v1/home');
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'recentGroups': [],
                'upcomingActivities': [],
                'financeSummary': {
                  'totalOwedByMe': '0.00',
                  'totalOwedToMe': '0.00',
                  'groups': [],
                },
                'actionsRequired': [],
                'recentUpdates': [],
              },
            ),
          );
        },
      ),
    );
    final result = await HomeRepository(HomeApi(dio)).load();
    expect(result.recentGroups, isEmpty);
    expect(result.financeSummary.owedByMe.decimal, '0.00');
  });

  test('controller publishes loading, success, error and retry', () async {
    final gateway = _Gateway();
    final completer = Completer<HomeResponse>();
    gateway.next = () => completer.future;
    final controller = HomeController(gateway);
    final pending = controller.load();
    expect(controller.loading, isTrue);
    completer.complete(_response());
    await pending;
    expect(controller.value!.recentGroups.single.id, 'group-1');
    gateway.next = () async => throw StateError('offline');
    await controller.load();
    expect(controller.value, isNotNull);
    expect(controller.error, isA<StateError>());
    gateway.next = () async => _response();
    await controller.load();
    expect(controller.error, isNull);
    expect(gateway.calls, 3);
    controller.dispose();
  });

  testWidgets('Home loads and renders empty section states', (tester) async {
    final gateway = _Gateway()
      ..next = () async => HomeResponse(
        [],
        [],
        HomeFinance(ExpenseMoney.zero, ExpenseMoney.zero, []),
        [],
        [],
      );
    await tester.pumpWidget(_screen(HomeController(gateway)));
    await tester.pumpAndSettle();
    expect(find.text('Không gian của bạn'), findsNothing);
    expect(
      find.text('Kết nối với nhóm. Cùng thực hiện những điều quan trọng.'),
      findsNothing,
    );
    expect(find.text('Nhóm của bạn'), findsOneWidget);
    expect(find.text('Hoạt động sắp tới'), findsOneWidget);
    expect(find.text('Tài chính'), findsOneWidget);
    expect(find.text('Cần xử lý'), findsOneWidget);
    expect(
      find.text('Bạn chưa có nhóm nào. Cùng bắt đầu một kết nối mới.'),
      findsOneWidget,
    );
    expect(find.text('Xem tất cả'), findsOneWidget);
    expect(find.text('Tạo hoặc tham gia nhóm'), findsOneWidget);
    expect(find.text('Không có việc cần xử lý.'), findsNothing);
    await _toggleSection(tester, 'Cần xử lý');
    expect(find.text('Không có việc cần xử lý.'), findsOneWidget);
    await _toggleSection(tester, 'Cần xử lý');
    await _toggleSection(tester, 'Hoạt động sắp tới');
    expect(find.text('Chưa có hoạt động sắp tới.'), findsOneWidget);
    await _toggleSection(tester, 'Hoạt động sắp tới');
    await _toggleSection(tester, 'Cập nhật gần đây');
    expect(find.text('Cập nhật gần đây'), findsOneWidget);
    expect(find.text('Chưa có cập nhật nào.'), findsOneWidget);
  });

  testWidgets('group preview offset is independent of vertical Home storage', (
    t,
  ) async {
    await t.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final base = _response();
    final gateway = _Gateway()
      ..next = () async => HomeResponse(
        [for (var i = 0; i < 8; i++) HomeGroup('g$i', 'Nhóm $i', null)],
        base.upcomingActivities,
        base.financeSummary,
        base.actionsRequired,
        base.recentUpdates,
      );
    await t.pumpWidget(_screen(HomeController(gateway)));
    await t.pumpAndSettle();
    ScrollableState horizontal() => t.state<ScrollableState>(
      find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
      ),
    );
    final vertical = t.state<ScrollableState>(
      find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      ),
    );
    expect(horizontal().position.pixels, 0);
    vertical.position.jumpTo(vertical.position.maxScrollExtent);
    await t.pumpAndSettle();
    vertical.position.jumpTo(0);
    await t.pumpAndSettle();
    expect(horizontal().position.pixels, 0);
    horizontal().position.jumpTo(120);
    await t.pumpAndSettle();
    vertical.position.jumpTo(vertical.position.maxScrollExtent);
    await t.pumpAndSettle();
    vertical.position.jumpTo(0);
    await t.pumpAndSettle();
    expect(horizontal().position.pixels, 120);
    expect(gateway.calls, 1);
  });

  testWidgets(
    'finance follows groups and independent folds retain state without fetching',
    (t) async {
      await t.binding.setSurfaceSize(const Size(500, 1500));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final gateway = _Gateway()..next = () async => _response();
      final controller = HomeController(gateway);
      await t.pumpWidget(_screen(controller));
      await t.pumpAndSettle();
      expect(
        t.getRect(find.text('Tài chính')).top,
        greaterThan(
          t.getRect(find.byKey(const ValueKey('home-your-groups'))).bottom,
        ),
      );
      expect(
        t.getRect(find.text('Cần xử lý')).top,
        greaterThan(t.getRect(find.text('Tài chính')).bottom),
      );
      expect(find.byKey(const Key('home-action-poll-1')), findsNothing);
      expect(find.byKey(const Key('home-activity-activity-1')), findsNothing);
      expect(find.byKey(const Key('home-update-update-1')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const PageStorageKey('home-section-actions')),
          matching: find.text('4'),
        ),
        findsOneWidget,
      );
      await _toggleSection(t, 'Cần xử lý');
      await _toggleSection(t, 'Hoạt động sắp tới');
      expect(find.byKey(const Key('home-action-poll-1')), findsOneWidget);
      expect(find.byKey(const Key('home-activity-activity-1')), findsOneWidget);
      await _toggleSection(t, 'Hoạt động sắp tới');
      expect(find.byKey(const Key('home-action-poll-1')), findsOneWidget);
      expect(gateway.calls, 1);
      await controller.load(silent: true);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('home-action-poll-1')), findsOneWidget);
      expect(find.byKey(const Key('home-activity-activity-1')), findsNothing);
      expect(gateway.calls, 2);
      await _toggleSection(t, 'Cần xử lý');
      expect(find.byKey(const Key('home-action-poll-1')), findsNothing);
    },
  );

  testWidgets('Home shows error and retries', (tester) async {
    final gateway = _Gateway()..next = () async => throw StateError('offline');
    await tester.pumpWidget(_screen(HomeController(gateway)));
    await tester.pumpAndSettle();
    expect(find.text('Không thể tải trang chủ.'), findsOneWidget);
    gateway.next = () async => _response();
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Study group'), findsWidgets);
  });

  testWidgets('Home delegates exact item IDs to existing route callbacks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _Gateway()..next = () async => _response();
    final opened = <String>[];
    await tester.pumpWidget(
      _screen(
        HomeController(gateway),
        group: (id) => opened.add('group:$id'),
        activity: (id) => opened.add('activity:$id'),
        balance: (id) => opened.add('balance:$id'),
        action: (item) => opened.add('${item.type.wire}:${item.targetId}'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-group-group-1')));
    await _toggleSection(tester, 'Hoạt động sắp tới');
    await tester.tap(find.byKey(const Key('home-activity-activity-1')));
    await _toggleSection(tester, 'Hoạt động sắp tới');
    await tester.ensureVisible(find.byKey(const Key('home-balance-group-1')));
    await tester.tap(find.byKey(const Key('home-balance-group-1')));
    await _toggleSection(tester, 'Cần xử lý');
    for (final id in ['activity-1', 'poll-1', 'task-1', 'settlement-1']) {
      await tester.ensureVisible(find.byKey(Key('home-action-$id')));
      await tester.tap(find.byKey(Key('home-action-$id')));
    }
    expect(opened, [
      'group:group-1',
      'activity:activity-1',
      'balance:group-1',
      'RSVP_REQUIRED:activity-1',
      'POLL_VOTE_REQUIRED:poll-1',
      'TASK_DUE:task-1',
      'SETTLEMENT_CONFIRMATION:settlement-1',
    ]);
  });

  testWidgets('Home recent update passes the exact notification to routing', (
    tester,
  ) async {
    final gateway = _Gateway()..next = () async => _response();
    NotificationItemModel? opened;
    await tester.pumpWidget(
      _screen(HomeController(gateway), update: (item) => opened = item),
    );
    await tester.pumpAndSettle();
    await _toggleSection(tester, 'Cập nhật gần đây');
    await tester.scrollUntilVisible(
      find.byKey(const Key('home-update-update-1')),
      200,
      scrollable: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      ),
    );
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(tester.element(find.byKey(const Key('home-update-update-1'))), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-update-update-1')));
    expect(opened?.notificationId, 'update-1');
    expect(opened?.target.targetId, 'group-1');
  });
}
