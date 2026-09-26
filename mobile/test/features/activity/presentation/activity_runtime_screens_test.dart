import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/activity/application/activity_controllers.dart';
import 'package:mobile/features/activity/data/activity_api.dart';
import 'package:mobile/features/activity/data/activity_models.dart';
import 'package:mobile/features/activity/data/activity_repository.dart';
import 'package:mobile/features/activity/presentation/screens/activity_runtime_screens.dart';

ActivityDetail _buildDetail({
  ActivityRsvpStatus rsvp = ActivityRsvpStatus.going,
  int? waitlistPosition,
  bool canEdit = true,
  bool canConfirm = true,
  bool canCancel = true,
  bool canComplete = false,
  bool canRsvp = true,
}) => ActivityDetail(
  id: 'act-1',
  groupId: 'grp-1',
  title: 'Weekend Soccer',
  description: 'Casual 7v7 soccer match',
  status: ActivityStatus.planning,
  startAt: DateTime.utc(2030, 6, 20, 15, 0),
  endAt: DateTime.utc(2030, 6, 20, 17, 0),
  timezone: 'Asia/Ho_Chi_Minh',
  location: const ActivityLocation(
    type: 'PHYSICAL',
    name: 'Soccer Field A',
    address: '123 Sport St, Hanoi',
    latitude: 21.0,
    longitude: 105.8,
  ),
  maxParticipants: 14,
  createdAt: DateTime.utc(2030, 6, 1),
  updatedAt: DateTime.utc(2030, 6, 1),
  creator: const ActivityCreator(
    userId: 'u1',
    username: 'coach_mike',
    displayName: 'Mike Coach',
  ),
  callerRsvpStatus: rsvp,
  callerWaitlistPosition: waitlistPosition,
  goingCount: 10,
  maybeCount: 2,
  notGoingCount: 1,
  waitlistCount: rsvp == ActivityRsvpStatus.waitlist ? 1 : 0,
  permissions: ActivityPermissions(
    canEdit: canEdit,
    canConfirm: canConfirm,
    canCancel: canCancel,
    canComplete: canComplete,
    canRsvp: canRsvp,
  ),
);

void main() {
  final sampleDetail = _buildDetail();

  group('ActivityListRuntimeScreen', () {
    testWidgets('renders list items, filter chips, and add button', (
      tester,
    ) async {
      final controller = _FakeListController(
        items: [
          ActivitySummary(
            id: 'act-1',
            title: 'Weekend Soccer',
            status: ActivityStatus.planning,
            startAt: DateTime.utc(2030, 6, 20, 15, 0),
            timezone: 'Asia/Ho_Chi_Minh',
            callerRsvpStatus: ActivityRsvpStatus.going,
            goingCount: 10,
            waitlistCount: 0,
            maxParticipants: 14,
          ),
        ],
      );

      String? openedId;
      await tester.pumpWidget(
        MaterialApp(
          home: ActivityListRuntimeScreen(
            groupId: 'grp-1',
            controller: controller,
            onOpen: (id) => openedId = id,
          ),
        ),
      );

      expect(find.text('Hoạt động'), findsOneWidget);
      expect(find.text('Weekend Soccer'), findsOneWidget);
      expect(find.text('Đang lên kế hoạch'), findsWidgets);
      expect(find.text('Tham gia'), findsWidgets);
      expect(find.byType(FloatingActionButton), findsOneWidget);

      await tester.tap(find.text('Weekend Soccer'));
      expect(openedId, 'act-1');
    });

    testWidgets('renders empty state when no activities exist', (tester) async {
      final controller = _FakeListController(items: []);

      await tester.pumpWidget(
        MaterialApp(
          home: ActivityListRuntimeScreen(
            groupId: 'grp-1',
            controller: controller,
            onOpen: (_) {},
          ),
        ),
      );

      expect(find.text('Chưa có hoạt động nào'), findsOneWidget);
    });
  });

  group('ActivityCreateRuntimeScreen', () {
    testWidgets(
      'renders progressive disclosure fields and creates unscheduled activity by default',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final controller = _FakeListController(items: []);

        await tester.pumpWidget(
          MaterialApp(
            home: ActivityCreateRuntimeScreen(
              groupId: 'grp-1',
              controller: controller,
            ),
          ),
        );

        expect(find.text('Tạo hoạt động'), findsWidgets);
        expect(find.byKey(const Key('activity-title')), findsOneWidget);
        expect(find.byKey(const Key('activity-description')), findsOneWidget);
        expect(
          find.byKey(const Key('activity-schedule-switch')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('activity-location-switch')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('activity-submit')), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('activity-title')),
          'Mua cầu lông',
        );
        await tester.tap(find.byKey(const Key('activity-submit')));
        await tester.pump();

        expect(controller.lastCreatedDraft?.title, 'Mua cầu lông');
        expect(controller.lastCreatedDraft?.startAt, isNull);
        expect(controller.lastCreatedDraft?.timezone, isNull);
      },
    );

    testWidgets('submits scheduled draft with location when toggled on', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = _FakeListController(items: []);

      await tester.pumpWidget(
        MaterialApp(
          home: ActivityCreateRuntimeScreen(
            groupId: 'grp-1',
            controller: controller,
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('activity-title')),
        'Morning Yoga',
      );
      // Toggle schedule on
      await tester.tap(find.byKey(const Key('activity-schedule-switch')));
      await tester.pumpAndSettle();

      // Toggle location on
      await tester.tap(find.byKey(const Key('activity-location-switch')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('activity-location-name')),
        'Yoga Studio',
      );
      await tester.enterText(
        find.byKey(const Key('activity-location-address')),
        '456 Calm St',
      );

      await tester.tap(find.byKey(const Key('activity-submit')));
      await tester.pump();

      expect(controller.lastCreatedDraft?.title, 'Morning Yoga');
      expect(controller.lastCreatedDraft?.startAt, isNotNull);
      expect(controller.lastCreatedDraft?.location?.name, 'Yoga Studio');
      expect(controller.lastCreatedDraft?.location?.address, '456 Calm St');
    });
  });

  group('ActivityDetailRuntimeScreen', () {
    testWidgets(
      'renders detail data, permission-driven buttons, and participation chips',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final controller = _FakeDetailController(detail: sampleDetail);

        await tester.pumpWidget(
          MaterialApp(
            home: ActivityDetailRuntimeScreen(
              activityId: 'act-1',
              controller: controller,
            ),
          ),
        );

        expect(find.text('Weekend Soccer'), findsOneWidget);
        expect(find.text('Casual 7v7 soccer match'), findsOneWidget);
        expect(find.textContaining('Soccer Field A'), findsOneWidget);
        expect(find.text('Chỉnh sửa'), findsOneWidget);
        expect(find.text('Xác nhận'), findsOneWidget);
        expect(find.text('Hủy'), findsOneWidget);
        expect(find.text('Hoàn thành'), findsNothing); // canComplete is false

        // RSVP chips in Vietnamese: Tham gia, Có thể tham gia, Không tham gia
        expect(find.widgetWithText(ChoiceChip, 'Tham gia'), findsOneWidget);
        expect(
          find.widgetWithText(ChoiceChip, 'Có thể tham gia'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(ChoiceChip, 'Không tham gia'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Trạng thái tham gia của bạn:'),
          findsOneWidget,
        );
        expect(find.textContaining('RSVP'), findsNothing);
      },
    );

    testWidgets(
      'renders waitlist banner and position when user is in WAITLIST',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final waitlistDetail = _buildDetail(
          rsvp: ActivityRsvpStatus.waitlist,
          waitlistPosition: 3,
        );
        final controller = _FakeDetailController(detail: waitlistDetail);

        await tester.pumpWidget(
          MaterialApp(
            home: ActivityDetailRuntimeScreen(
              activityId: 'act-1',
              controller: controller,
            ),
          ),
        );

        expect(
          find.textContaining('Bạn đang trong danh sách chờ (#3)'),
          findsOneWidget,
        );
      },
    );
  });

  group('ActivityEditRuntimeScreen', () {
    testWidgets('pre-populates existing values including structured location', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = _FakeDetailController();

      await tester.pumpWidget(
        MaterialApp(
          home: ActivityEditRuntimeScreen(
            detail: sampleDetail,
            controller: controller,
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is TextField && w.controller?.text == 'Weekend Soccer',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is TextField && w.controller?.text == 'Casual 7v7 soccer match',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is TextField && w.controller?.text == 'Soccer Field A',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is TextField && w.controller?.text == '123 Sport St, Hanoi',
        ),
        findsOneWidget,
      );
    });
  });

  group('ActivityParticipantsRuntimeScreen', () {
    testWidgets(
      'renders public-safe identity fields and no private auth fields',
      (tester) async {
        final participants = [
          const ActivityParticipant(
            userId: 'u1',
            username: 'mike_safe',
            displayName: 'Mike Safe',
            rsvpStatus: ActivityRsvpStatus.going,
          ),
          const ActivityParticipant(
            userId: 'u2',
            username: 'anna_waitlist',
            displayName: 'Anna Queued',
            rsvpStatus: ActivityRsvpStatus.waitlist,
            waitlistSequence: 1,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: ActivityParticipantsRuntimeScreen(participants: participants),
          ),
        );

        expect(find.text('Mike Safe'), findsOneWidget);
        expect(find.text('@mike_safe'), findsOneWidget);
        expect(find.text('Anna Queued'), findsOneWidget);
        expect(find.text('@anna_waitlist'), findsOneWidget);
        expect(find.text('CHỜ · #1'), findsOneWidget);

        // Verify no sensitive auth fields
        expect(find.textContaining('email'), findsNothing);
        expect(find.textContaining('password'), findsNothing);
        expect(find.textContaining('token'), findsNothing);
      },
    );
  });

  group('ActivityWaitlistRuntimeScreen', () {
    testWidgets('renders queue position and change participation action', (
      tester,
    ) async {
      final waitlistDetail = _buildDetail(
        rsvp: ActivityRsvpStatus.waitlist,
        waitlistPosition: 2,
      );

      var rsvpChanged = false;
      await tester.pumpWidget(
        MaterialApp(
          home: ActivityWaitlistRuntimeScreen(
            detail: waitlistDetail,
            onChangeRsvp: () => rsvpChanged = true,
          ),
        ),
      );

      expect(find.text('Bạn đang ở vị trí #2 trong hàng đợi'), findsOneWidget);
      expect(find.text('Thay đổi trạng thái tham gia'), findsOneWidget);
      expect(find.textContaining('RSVP'), findsNothing);
      await tester.tap(find.text('Thay đổi trạng thái tham gia'));
      expect(rsvpChanged, isTrue);
    });
  });
}

class _FakeListController extends ActivityListController {
  ActivityDraft? lastCreatedDraft;

  _FakeListController({required List<ActivitySummary> items})
    : super(_DummyRepo()) {
    value = ActivityListState(
      items.isEmpty ? ActivityLoadPhase.empty : ActivityLoadPhase.data,
      items: items,
    );
  }

  @override
  Future<void> load(String groupId) async {}

  @override
  Future<ActivityDetail?> create(String groupId, ActivityDraft draft) async {
    lastCreatedDraft = draft;
    return ActivityDetail(
      id: 'act-new',
      groupId: groupId,
      title: draft.title,
      status: ActivityStatus.planning,
      startAt: draft.startAt,
      timezone: draft.timezone,
      createdAt: DateTime.utc(2030, 1, 1),
      updatedAt: DateTime.utc(2030, 1, 1),
      creator: const ActivityCreator(userId: 'u1'),
      callerRsvpStatus: ActivityRsvpStatus.going,
      goingCount: 1,
      maybeCount: 0,
      notGoingCount: 0,
      waitlistCount: 0,
      permissions: const ActivityPermissions(
        canEdit: true,
        canConfirm: true,
        canCancel: true,
        canComplete: false,
        canRsvp: true,
      ),
    );
  }
}

class _FakeDetailController extends ActivityDetailController {
  _FakeDetailController({ActivityDetail? detail}) : super(_DummyRepo()) {
    if (detail != null) {
      value = ActivityDetailState(detail: detail);
    }
  }

  @override
  Future<void> load(String activityId) async {}

  @override
  Future<bool> rsvp(String activityId, ActivityRsvpStatus status) async => true;
  @override
  Future<bool> confirm(String activityId) async => true;
  @override
  Future<bool> cancel(String activityId, {String? reason}) async => true;
  @override
  Future<bool> complete(String activityId) async => true;
}

class _DummyRepo extends ActivityRepository {
  _DummyRepo() : super(api: ActivityApi(Dio()));
}
