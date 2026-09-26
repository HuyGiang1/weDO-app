import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/paged_response.dart';
import 'package:mobile/features/activity/application/activity_controllers.dart';
import 'package:mobile/features/activity/data/activity_api.dart';
import 'package:mobile/features/activity/data/activity_failure.dart';
import 'package:mobile/features/activity/data/activity_models.dart';
import 'package:mobile/features/activity/data/activity_repository.dart';

ActivityDetail _testDetail({
  ActivityPermissions permissions = const ActivityPermissions(
    canEdit: true,
    canConfirm: true,
    canCancel: true,
    canComplete: false,
    canRsvp: true,
  ),
  ActivityRsvpStatus rsvp = ActivityRsvpStatus.noResponse,
  int? queue,
}) => ActivityDetail(
  id: 'a', groupId: 'g', title: 'Run', status: ActivityStatus.planning,
  startAt: DateTime.utc(2030), timezone: 'Asia/Ho_Chi_Minh',
  createdAt: DateTime.utc(2030), updatedAt: DateTime.utc(2030),
  creator: const ActivityCreator(userId: 'owner'), callerRsvpStatus: rsvp,
  callerWaitlistPosition: queue, goingCount: 1, maybeCount: 0,
  notGoingCount: 0, waitlistCount: queue == null ? 0 : 1,
  permissions: permissions,
);

class FakeActivityRepository extends ActivityRepository {
  FakeActivityRepository() : super(api: ActivityApi(Dio()));
  PagedResponse<ActivitySummary> page = const PagedResponse(
    items: [], page: 0, size: 30, totalElements: 0, totalPages: 0, hasNext: false,
  );
  ActivityDetail current = _testDetail();
  List<ActivityParticipant> participantList = const [];
  ActivityException? failure;
  String? listGroup, createdGroup, detailId, updatedId, rsvpId;
  int? listPage, listSize;
  Map<String, dynamic>? updateBody;
  ActivityRsvpStatus? sentRsvp;

  void _fail() { if (failure != null) throw failure!; }
  @override Future<PagedResponse<ActivitySummary>> list(String groupId, {int page = 0, int size = 30}) async {
    listGroup = groupId; listPage = page; listSize = size; _fail(); return this.page;
  }
  @override Future<ActivityDetail> create(String groupId, ActivityDraft draft) async {
    createdGroup = groupId; _fail(); return current;
  }
  @override Future<ActivityDetail> detail(String id) async { detailId = id; _fail(); return current; }
  @override Future<List<ActivityParticipant>> participants(String id) async { _fail(); return participantList; }
  @override Future<ActivityDetail> update(String id, Map<String, dynamic> body) async { updatedId = id; updateBody = body; _fail(); return current; }
  @override Future<ActivityDetail> confirm(String id) async { _fail(); return current; }
  @override Future<ActivityDetail> cancel(String id, {String? reason}) async { _fail(); return current; }
  @override Future<ActivityDetail> complete(String id) async { _fail(); return current; }
  @override Future<ActivityRsvp> rsvp(String id, ActivityRsvpStatus status) async {
    rsvpId = id; sentRsvp = status; _fail(); return const ActivityRsvp(status: ActivityRsvpStatus.going);
  }
}

void main() {
  test('list loads page zero size thirty and preserves server order', () async {
    final repo = FakeActivityRepository();
    repo.page = PagedResponse(
      items: [
        ActivitySummary(id: 'second', title: 'Second', status: ActivityStatus.planning, startAt: DateTime.utc(2030), timezone: 'Asia/Ho_Chi_Minh', goingCount: 0, waitlistCount: 0, callerRsvpStatus: ActivityRsvpStatus.noResponse),
        ActivitySummary(id: 'first', title: 'First', status: ActivityStatus.planning, startAt: DateTime.utc(2030), timezone: 'Asia/Ho_Chi_Minh', goingCount: 0, waitlistCount: 0, callerRsvpStatus: ActivityRsvpStatus.noResponse),
      ], page: 0, size: 30, totalElements: 2, totalPages: 1, hasNext: false,
    );
    final controller = ActivityListController(repo);
    await controller.load('group-id');
    expect(repo.listGroup, 'group-id'); expect(repo.listPage, 0); expect(repo.listSize, 30);
    expect(controller.value.items.map((e) => e.id), ['second', 'first']);
  });

  test('empty list has an explicit empty state', () async {
    final controller = ActivityListController(FakeActivityRepository());
    await controller.load('g');
    expect(controller.value.phase, ActivityLoadPhase.empty);
  });

  test('typed list failure is preserved for retry feedback', () async {
    final repo = FakeActivityRepository()..failure = const ActivityException(ActivityFailure(ActivityFailureType.permission));
    final controller = ActivityListController(repo); await controller.load('g');
    expect(controller.value.phase, ActivityLoadPhase.error);
    expect(controller.value.failure?.type, ActivityFailureType.permission);
  });

  test('create uses exact group id then refreshes authoritative list', () async {
    final repo = FakeActivityRepository(); final controller = ActivityListController(repo);
    final result = await controller.create('exact-group', ActivityDraft(title: 'Run', timezone: 'Asia/Ho_Chi_Minh', startAt: DateTime.utc(2030)));
    expect(result?.id, 'a'); expect(repo.createdGroup, 'exact-group'); expect(repo.listGroup, 'exact-group');
  });

  test('detail load uses exact activity id and participant public projection', () async {
    final repo = FakeActivityRepository()..participantList = const [ActivityParticipant(userId: 'u', username: 'safe', rsvpStatus: ActivityRsvpStatus.going)];
    final controller = ActivityDetailController(repo); await controller.load('activity-id');
    expect(repo.detailId, 'activity-id'); expect(controller.value.participants.single.username, 'safe');
  });

  test('mutation adopts authoritative detail and refreshes participants', () async {
    final repo = FakeActivityRepository()..current = _testDetail(permissions: const ActivityPermissions(canEdit: false, canConfirm: false, canCancel: false, canComplete: true, canRsvp: false));
    final controller = ActivityDetailController(repo); await controller.confirm('a');
    expect(controller.value.detail?.permissions.canEdit, isFalse);
    expect(controller.value.detail?.permissions.canComplete, isTrue);
  });

  test('RSVP sends selectable GOING and reloads waitlist status from server', () async {
    final repo = FakeActivityRepository()..current = _testDetail(rsvp: ActivityRsvpStatus.waitlist, queue: 2);
    final controller = ActivityDetailController(repo); final ok = await controller.rsvp('a', ActivityRsvpStatus.going);
    expect(ok, isTrue); expect(repo.rsvpId, 'a'); expect(repo.sentRsvp, ActivityRsvpStatus.going);
    expect(controller.value.detail?.callerRsvpStatus, ActivityRsvpStatus.waitlist);
    expect(controller.value.detail?.callerWaitlistPosition, 2);
  });

  test('server-only WAITLIST is never sent by controller', () async {
    final repo = FakeActivityRepository(); final controller = ActivityDetailController(repo);
    expect(await controller.rsvp('a', ActivityRsvpStatus.waitlist), isFalse);
    expect(repo.sentRsvp, isNull);
  });

  test('typed mutation failure keeps old detail without fake success', () async {
    final repo = FakeActivityRepository(); final controller = ActivityDetailController(repo);
    await controller.load('a'); repo.failure = const ActivityException(ActivityFailure(ActivityFailureType.closed));
    expect(await controller.cancel('a'), isFalse);
    expect(controller.value.detail?.id, 'a'); expect(controller.value.failure?.type, ActivityFailureType.closed);
  });
}
