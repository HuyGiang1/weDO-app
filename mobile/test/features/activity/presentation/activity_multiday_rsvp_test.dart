import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/activity/application/activity_controllers.dart';
import 'package:mobile/features/activity/data/activity_api.dart';
import 'package:mobile/features/activity/data/activity_models.dart';
import 'package:mobile/features/activity/data/activity_repository.dart';
import 'package:mobile/features/activity/presentation/screens/activity_runtime_screens.dart';

class _FakeListController extends ActivityListController {
  ActivityDraft? lastCreatedDraft;

  _FakeListController() : super(ActivityRepository(api: ActivityApi(Dio())));

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
      endAt: draft.endAt,
      timezone: draft.timezone,
      createdAt: DateTime.utc(2030, 1, 1),
      updatedAt: DateTime.utc(2030, 1, 1),
      creator: const ActivityCreator(userId: 'u1'),
      callerRsvpStatus: ActivityRsvpStatus.noResponse,
      goingCount: 0,
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
  _FakeDetailController({ActivityDetail? detail})
      : super(ActivityRepository(api: ActivityApi(Dio()))) {
    if (detail != null) {
      value = ActivityDetailState(detail: detail);
    }
  }

  @override
  Future<void> load(String activityId) async {}
}

void main() {
  group('Multi-Day Activity Scheduling & RSVP UI Tests', () {
    testWidgets('Schedule OFF produces null startAt, endAt, timezone', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = _FakeListController();

      await tester.pumpWidget(MaterialApp(
        home: ActivityCreateRuntimeScreen(groupId: 'grp-1', controller: controller),
      ));

      await tester.enterText(find.byKey(const Key('activity-title')), 'Unscheduled Event');
      await tester.tap(find.byKey(const Key('activity-submit')));
      await tester.pump();

      expect(controller.lastCreatedDraft?.startAt, isNull);
      expect(controller.lastCreatedDraft?.endAt, isNull);
      expect(controller.lastCreatedDraft?.timezone, isNull);
    });

    testWidgets('Detail Screen shows closed contextual banner and NO "RSVP" error when canRsvp=false', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final completedDetail = ActivityDetail(
        id: 'act-completed',
        groupId: 'grp-1',
        title: 'Completed Tour',
        status: ActivityStatus.completed,
        startAt: DateTime.utc(2026, 3, 30, 8, 0),
        endAt: DateTime.utc(2026, 3, 30, 12, 0),
        timezone: 'Asia/Ho_Chi_Minh',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        creator: const ActivityCreator(userId: 'u1', username: 'tour_guide'),
        callerRsvpStatus: ActivityRsvpStatus.going,
        goingCount: 5,
        maybeCount: 0,
        notGoingCount: 0,
        waitlistCount: 0,
        permissions: const ActivityPermissions(
          canEdit: false,
          canConfirm: false,
          canCancel: false,
          canComplete: false,
          canRsvp: false,
        ),
      );

      final detailController = _FakeDetailController(detail: completedDetail);

      await tester.pumpWidget(MaterialApp(
        home: ActivityDetailRuntimeScreen(
          activityId: 'act-completed',
          controller: detailController,
        ),
      ));

      expect(find.text('Hoạt động đã kết thúc.'), findsOneWidget);
      expect(find.text('Trạng thái của bạn: Tham gia'), findsOneWidget);
      expect(find.text('Bạn có tham gia không?'), findsNothing);
      expect(find.text('RSVP hiện đã bị khóa cho hoạt động này.'), findsNothing);
    });

    testWidgets('Detail Screen shows cancelled contextual banner when cancelled and canRsvp=false', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final cancelledDetail = ActivityDetail(
        id: 'act-cancelled',
        groupId: 'grp-1',
        title: 'Cancelled Match',
        status: ActivityStatus.cancelled,
        startAt: DateTime.utc(2026, 3, 30, 8, 0),
        endAt: DateTime.utc(2026, 3, 30, 12, 0),
        timezone: 'Asia/Ho_Chi_Minh',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        creator: const ActivityCreator(userId: 'u1', username: 'tour_guide'),
        callerRsvpStatus: ActivityRsvpStatus.noResponse,
        goingCount: 0,
        maybeCount: 0,
        notGoingCount: 0,
        waitlistCount: 0,
        permissions: const ActivityPermissions(
          canEdit: false,
          canConfirm: false,
          canCancel: false,
          canComplete: false,
          canRsvp: false,
        ),
      );

      final detailController = _FakeDetailController(detail: cancelledDetail);

      await tester.pumpWidget(MaterialApp(
        home: ActivityDetailRuntimeScreen(
          activityId: 'act-cancelled',
          controller: detailController,
        ),
      ));

      expect(find.text('Hoạt động đã bị hủy.'), findsOneWidget);
      expect(find.text('Bạn có tham gia không?'), findsNothing);
      expect(find.text('RSVP hiện đã bị khóa cho hoạt động này.'), findsNothing);
    });

    testWidgets('Detail Screen shows interactive RSVP chips when canRsvp=true', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final openDetail = ActivityDetail(
        id: 'act-open',
        groupId: 'grp-1',
        title: 'Open Match',
        status: ActivityStatus.planning,
        startAt: DateTime.utc(2026, 4, 1, 8, 0),
        endAt: DateTime.utc(2026, 4, 1, 10, 0),
        timezone: 'Asia/Ho_Chi_Minh',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        creator: const ActivityCreator(userId: 'u1', username: 'organizer'),
        callerRsvpStatus: ActivityRsvpStatus.noResponse,
        goingCount: 0,
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

      final detailController = _FakeDetailController(detail: openDetail);

      await tester.pumpWidget(MaterialApp(
        home: ActivityDetailRuntimeScreen(
          activityId: 'act-open',
          controller: detailController,
        ),
      ));

      expect(find.text('Bạn có tham gia không?'), findsOneWidget);
      expect(find.text('Chọn trạng thái tham gia của bạn:'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Tham gia'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Có thể tham gia'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Không tham gia'), findsOneWidget);
      expect(find.text('RSVP hiện đã bị khóa cho hoạt động này.'), findsNothing);
    });

    testWidgets('Same-day and multi-day creation build correct UTC startAt and endAt', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = _FakeListController();

      await tester.pumpWidget(MaterialApp(
        home: ActivityCreateRuntimeScreen(groupId: 'grp-1', controller: controller),
      ));

      await tester.enterText(find.byKey(const Key('activity-title')), 'Multi-day Trip');
      await tester.tap(find.byKey(const Key('activity-schedule-switch')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('activity-end-time-switch')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('activity-start-date-button')), findsOneWidget);
      expect(find.byKey(const Key('activity-start-time-button')), findsOneWidget);
      expect(find.byKey(const Key('activity-end-date-button')), findsOneWidget);
      expect(find.byKey(const Key('activity-end-time-button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('activity-submit')));
      await tester.pump();

      expect(controller.lastCreatedDraft?.startAt, isNotNull);
      expect(controller.lastCreatedDraft?.endAt, isNotNull);
      expect(controller.lastCreatedDraft?.endAt!.isAfter(controller.lastCreatedDraft!.startAt!), isTrue);
    });

    testWidgets('Edit Screen prepopulates multi-day dates correctly', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final multiDayDetail = ActivityDetail(
        id: 'act-multi',
        groupId: 'grp-1',
        title: 'Camp 2026',
        status: ActivityStatus.planning,
        startAt: DateTime.utc(2026, 3, 31, 14, 0),
        endAt: DateTime.utc(2026, 4, 2, 10, 0),
        timezone: 'Asia/Ho_Chi_Minh',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        creator: const ActivityCreator(userId: 'u1'),
        callerRsvpStatus: ActivityRsvpStatus.noResponse,
        goingCount: 0,
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

      final detailController = _FakeDetailController(detail: multiDayDetail);

      await tester.pumpWidget(MaterialApp(
        home: ActivityEditRuntimeScreen(detail: multiDayDetail, controller: detailController),
      ));

      expect(find.text('Camp 2026'), findsOneWidget);
      expect(find.text('Có thời gian cụ thể'), findsOneWidget);
      expect(find.byKey(const Key('activity-edit-start-date-button')), findsOneWidget);
      expect(find.byKey(const Key('activity-edit-end-date-button')), findsOneWidget);
    });
  });
}
