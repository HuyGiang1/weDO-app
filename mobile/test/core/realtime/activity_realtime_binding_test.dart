import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/realtime/realtime_binding.dart';
import 'package:mobile/core/realtime/realtime_sync.dart';
import 'package:mobile/features/activity/application/activity_controllers.dart';
import 'package:mobile/features/activity/data/activity_models.dart';
import 'package:mobile/features/activity/presentation/screens/activity_runtime_screens.dart';
import 'package:mobile/features/chat/data/chat_realtime_client.dart';
import '../../features/activity/application/activity_controllers_test.dart' show FakeActivityRepository;

void main() {
  testWidgets('remote promotion visibly updates RSVP count waitlist and open participants', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeActivityRepository()
      ..current = _detail(waiting: true)
      ..participantList = const [
        ActivityParticipant(userId: 'b', displayName: 'QA B', rsvpStatus: ActivityRsvpStatus.going),
        ActivityParticipant(userId: 'a', displayName: 'QA A', rsvpStatus: ActivityRsvpStatus.waitlist, waitlistSequence: 1),
      ];
    final controller = ActivityDetailController(repository);
    final sync = RealtimeSync(const NoopChatRealtimeClient());
    await tester.pumpWidget(RealtimeHost(sync: sync, child: MaterialApp(
      home: ActivityDetailRuntimeScreen(activityId: 'a', controller: controller),
    )));
    await tester.pumpAndSettle();
    expect(find.text('1 / 1 người tham gia'), findsOneWidget);
    expect(find.text('Danh sách chờ: 1 người'), findsOneWidget);
    expect(find.byKey(const ValueKey('waitlist-state')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('waitlist-state')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('waitlist-state')));
    await tester.pumpAndSettle();
    expect(find.text('Bạn đang ở vị trí #1 trong hàng đợi'), findsOneWidget);
    repository.current = _detail(waiting: false);
    repository.participantList = const [
      ActivityParticipant(userId: 'a', displayName: 'QA A', rsvpStatus: ActivityRsvpStatus.going),
    ];
    sync.accept(_rsvpEvent('promoted'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('Trạng thái đăng ký đã được cập nhật'), findsOneWidget);
    expect(find.text('Bạn đang ở vị trí #1 trong hàng đợi'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Danh sách chờ: 0 người'), findsOneWidget);
    expect(find.byKey(const ValueKey('waitlist-state')), findsNothing);
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Tham gia')).selected, isTrue);
    await tester.ensureVisible(find.text('Người tham gia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Người tham gia'));
    await tester.pumpAndSettle();
    expect(find.text('QA A'), findsOneWidget);
    expect(find.text('QA B'), findsNothing);
    repository.current = _detail(waiting: false, going: 0);
    repository.participantList = const [];
    sync.accept(_rsvpEvent('left'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('QA A'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('0 / 1 người tham gia'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    await tester.runAsync(sync.dispose);
    expect(tester.takeException(), isNull);
  });

  test('late resync cannot replace newer state or notify a disposed controller', () async {
    final repository = _DelayedRepository();
    final controller = ActivityDetailController(repository);
    final old = Completer<ActivityDetail>();
    repository.next = old.future;
    final pending = controller.resync('a');
    repository.next = Future.value(_detail(waiting: false, going: 0));
    await controller.resync('a');
    old.complete(_detail(waiting: true));
    await pending;
    expect(controller.value.detail!.goingCount, 0);
    var notifications = 0;
    controller.addListener(() => notifications++);
    final disposed = Completer<ActivityDetail>();
    repository.next = disposed.future;
    final last = controller.resync('a');
    controller.dispose();
    disposed.complete(_detail(waiting: true));
    await last;
    expect(notifications, 0);
  });
  testWidgets('remote RSVP silently updates visible detail without manual refresh', (tester) async {
    final repository = FakeActivityRepository()..participantList = const [
      ActivityParticipant(userId: 'member', displayName: 'QA Member', rsvpStatus: ActivityRsvpStatus.going),
    ];
    final controller = ActivityDetailController(repository);
    final sync = RealtimeSync(const NoopChatRealtimeClient());
    await tester.pumpWidget(RealtimeHost(sync: sync, child: MaterialApp(
      home: ActivityDetailRuntimeScreen(activityId: 'a', controller: controller),
    )));
    await tester.pumpAndSettle();
    expect(controller.value.participants.length, 1);
    repository.participantList = const [];
    sync.accept({
      'type': 'DOMAIN_CHANGED', 'eventId': 'leave-1',
      'eventType': 'ACTIVITY_RSVP_CHANGED', 'scope': 'activity:a', 'aggregateId': 'a',
    });
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(controller.value.participants, isEmpty);
    expect(controller.value.loading, isFalse);
    expect(controller.value.detail, isNotNull);
    // Event from another Activity cannot invalidate this resource.
    repository.participantList = const [ActivityParticipant(userId: 'other', rsvpStatus: ActivityRsvpStatus.going)];
    sync.accept({
      'type': 'DOMAIN_CHANGED', 'eventId': 'other-1',
      'eventType': 'ACTIVITY_RSVP_CHANGED', 'scope': 'activity:other', 'aggregateId': 'other',
    });
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.value.participants, isEmpty);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    await tester.runAsync(sync.dispose);
    expect(tester.takeException(), isNull);
  });
}

Map<String, dynamic> _rsvpEvent(String id) => {
  'type': 'DOMAIN_CHANGED', 'eventId': id, 'eventType': 'ACTIVITY_RSVP_CHANGED',
  'scope': 'activity:a', 'aggregateType': 'ACTIVITY', 'aggregateId': 'a',
};

ActivityDetail _detail({required bool waiting, int going = 1}) => ActivityDetail(
  id: 'a', groupId: 'g', title: 'RSVP slice', status: ActivityStatus.planning,
  createdAt: DateTime.utc(2030), updatedAt: DateTime.utc(2030),
  creator: const ActivityCreator(userId: 'owner'), maxParticipants: 1,
  callerRsvpStatus: waiting ? ActivityRsvpStatus.waitlist : ActivityRsvpStatus.going,
  callerWaitlistPosition: waiting ? 1 : null, goingCount: going, maybeCount: 0,
  notGoingCount: 0, waitlistCount: waiting ? 1 : 0,
  permissions: const ActivityPermissions(canEdit: false, canConfirm: false,
    canCancel: false, canComplete: false, canRsvp: true),
);

class _DelayedRepository extends FakeActivityRepository {
  late Future<ActivityDetail> next;
  @override
  Future<ActivityDetail> detail(String id) => next;
}
