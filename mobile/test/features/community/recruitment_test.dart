import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/realtime/realtime_binding.dart';
import 'package:mobile/core/realtime/realtime_sync.dart';
import 'package:mobile/features/chat/data/chat_realtime_client.dart';
import 'package:mobile/features/community/data/recruitment_api.dart';
import 'package:mobile/features/community/presentation/recruitment_screen.dart';
import 'package:mobile/features/moments/data/moment_models.dart';

void main() {
  late Adapter adapter;
  late RecruitmentApi api;
  late RealtimeSync sync;
  Future<void> mount(
    WidgetTester t,
    Widget Function() child, {
    Brightness brightness = Brightness.light,
    Size size = const Size(500, 1000),
  }) async {
    await t.binding.setSurfaceSize(size);
    adapter = Adapter();
    api = TestApi(
      Dio(BaseOptions(baseUrl: 'https://fixture'))..httpClientAdapter = adapter,
    );
    sync = RealtimeSync(const NoopChatRealtimeClient());
    await t.pumpWidget(
      RealtimeHost(
        sync: sync,
        child: MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: child(),
        ),
      ),
    );
    await t.pumpAndSettle();
    addTearDown(() async {
      await t.pumpWidget(const SizedBox());
      await t.runAsync(sync.dispose);
      await t.binding.setSurfaceSize(null);
    });
  }

  Future<void> hint(
    WidgetTester t,
    String scope,
    String type, {
    String id = 'p',
    String? eventId,
  }) async {
    sync.accept({
      'type': 'DOMAIN_CHANGED',
      'scope': scope,
      'eventId': eventId ?? '$scope-$type',
      'eventType': type,
      'aggregateId': id,
    });
    await t.pump(const Duration(milliseconds: 100));
    await t.pumpAndSettle();
  }

  testWidgets(
    'outsider preview is minimal and join remains pending without membership',
    (t) async {
      await mount(t, () => RecruitmentPreview(api: api, post: 'p'));
      expect(find.text('R6 QA group'), findsOneWidget);
      expect(find.text('Chat'), findsNothing);
      await t.tap(find.text('Yêu cầu tham gia'));
      await t.pumpAndSettle();
      expect(adapter.joins, 1);
      expect(find.text('Đang chờ duyệt'), findsOneWidget);
      expect(adapter.member, isFalse);
      expect(find.text('0/3 người đã được duyệt · Còn 3 chỗ'), findsOneWidget);
      await t.tap(find.text('Hủy yêu cầu'));
      await t.pumpAndSettle();
      expect(find.text('Đã hủy yêu cầu'), findsOneWidget);
    },
  );
  testWidgets(
    'approval hint converges to Member and Filled without resubmitting mutation',
    (t) async {
      await mount(t, () => RecruitmentPreview(api: api, post: 'p'));
      adapter.member = true;
      adapter.approved = 3;
      adapter.status = 'FILLED';
      await hint(t, 'post:p', 'COMMUNITY_RECRUITMENT_CHANGED');
      expect(find.text('Bạn là thành viên'), findsOneWidget);
      expect(find.text('Đã đủ người'), findsOneWidget);
      expect(find.text('Yêu cầu tham gia'), findsNothing);
      expect(adapter.joins, 0);
    },
  );
  testWidgets(
    'offline retains preview read-only; resubscribe gets authoritative state',
    (t) async {
      await mount(t, () => RecruitmentPreview(api: api, post: 'p'));
      adapter.offline = true;
      await hint(t, 'post:p', 'COMMUNITY_RECRUITMENT_CHANGED');
      expect(find.text('R6 QA group'), findsOneWidget);
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Yêu cầu tham gia'),
            )
            .onPressed,
        isNull,
      );
      expect(t.takeException(), isNull);
      adapter.offline = false;
      adapter.member = true;
      sync.accept({'type': 'SCOPE_SUBSCRIBED', 'scope': 'post:p'});
      await t.pump(const Duration(milliseconds: 100));
      await t.pumpAndSettle();
      expect(find.text('Bạn là thành viên'), findsOneWidget);
    },
  );
  testWidgets('scope revocation rejects protected late results', (t) async {
    await mount(t, () => RecruitmentPreview(api: api, post: 'p'));
    adapter.gate = Completer<void>();
    sync.accept({
      'type': 'DOMAIN_CHANGED',
      'scope': 'post:p',
      'eventId': 'late',
      'eventType': 'COMMUNITY_RECRUITMENT_CHANGED',
      'aggregateId': 'p',
    });
    await t.pump(const Duration(milliseconds: 100));
    sync.accept({'type': 'SCOPE_REVOKED', 'scope': 'post:p'});
    adapter.denied = true;
    await t.pump();
    expect(find.text('R6 QA group'), findsNothing);
    adapter.gate!.complete();
    adapter.gate = null;
    await t.pumpAndSettle();
    expect(find.text('R6 QA group'), findsNothing);
    expect(t.takeException(), isNull);
  });
  for (final approve in [true, false]) {
    testWidgets(
      'authorized reviewer ${approve ? 'approves' : 'rejects'} canonical request',
      (t) async {
        await mount(t, () => RecruitmentRequests(api: api, post: 'p'));
        await t.tap(find.byTooltip(approve ? 'Duyệt' : 'Từ chối'));
        await t.pumpAndSettle();
        expect(adapter.resolutions.single, approve ? 'approve' : 'reject');
        expect(
          find.text('Chưa có yêu cầu chờ duyệt qua bài này.'),
          findsOneWidget,
        );
      },
    );
  }
  testWidgets(
    'review scope loss clears applicant names immediately while offline',
    (t) async {
      await mount(t, () => RecruitmentRequests(api: api, post: 'p'));
      expect(find.text('Outsider QA'), findsOneWidget);
      adapter.offline = true;
      sync.accept({'type': 'SCOPE_REVOKED', 'scope': 'review:p'});
      await t.pump();
      expect(find.text('Outsider QA'), findsNothing);
      await t.pump(const Duration(milliseconds: 100));
      await t.pumpAndSettle();
      expect(find.text('Outsider QA'), findsNothing);
    },
  );
  testWidgets(
    'owner can close recruitment and outsider cannot see management controls',
    (t) async {
      await mount(t, () {
        adapter.manager = true;
        return RecruitmentPreview(api: api, post: 'p');
      });
      await t.tap(find.text('Đóng tuyển thành viên'));
      await t.pumpAndSettle();
      expect(adapter.status, 'CLOSED');
      expect(find.text('Đã đóng'), findsOneWidget);
      expect(adapter.closeCalls, 1);
    },
  );
  testWidgets(
    'composer selects authorized group and same-group activity with stable retry UUID',
    (t) async {
      await mount(t, () => RecruitmentComposer(api: api));
      await t.tap(find.text('Nhóm tuyển thành viên'));
      await t.pumpAndSettle();
      await t.tap(find.text('R6 QA group').last);
      await t.pumpAndSettle();
      await t.tap(find.text('Chỉ tuyển cho nhóm'));
      await t.pumpAndSettle();
      await t.tap(find.text('R6 QA Activity').last);
      await t.pumpAndSettle();
      await t.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField && w.decoration?.labelText == 'Bạn đang tìm ai?',
        ),
        'Tìm 3 người QA',
      );
      await t.scrollUntilVisible(
        find.text('Đăng tin tuyển'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      adapter.failCreate = true;
      await t.ensureVisible(find.text('Đăng tin tuyển'));
      await t.pumpAndSettle();
      await t.tap(find.text('Đăng tin tuyển'));
      await t.pumpAndSettle();
      adapter.failCreate = false;
      t.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).hideCurrentSnackBar();
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Đăng tin tuyển'));
      await t.pumpAndSettle();
      await t.tap(find.text('Đăng tin tuyển'));
      await t.pumpAndSettle();
      expect(adapter.commands.length, 2);
      expect(adapter.commands.toSet().length, 1);
      expect(adapter.created!['groupId'], 'g');
      expect(adapter.created!['activityId'], 'a');
      expect(adapter.created!['requestedCount'], 3);
    },
  );
  testWidgets(
    'discovery filters use real REST and new posts do not jump or refetch',
    (t) async {
      await mount(t, () => RecruitmentDiscovery(api: api, viewer: 'viewer'));
      final reads = adapter.discoveries;
      await hint(t, 'community:viewer', 'COMMUNITY_RECRUITMENT_CREATED');
      expect(adapter.discoveries, reads);
      expect(find.text('Có bài tuyển mới · Xem cập nhật'), findsOneWidget);
      await t.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.labelText == 'Từ khóa tuyển thành viên',
        ),
        'Ba Vì',
      );
      await t.tap(find.text('Tìm kiếm'));
      await t.pumpAndSettle();
      expect(adapter.filters.last['keyword'], 'Ba Vì');
    },
  );
  testWidgets(
    'discovery preserves loaded depth through reconnect and deduplicates pages',
    (t) async {
      await mount(t, () {
        adapter.paginated = true;
        return RecruitmentDiscovery(api: api, viewer: 'viewer');
      });
      await t.scrollUntilVisible(
        find.text('Xem tin cũ hơn'),
        400,
        scrollable: find.byType(Scrollable).last,
      );
      await t.tap(find.text('Xem tin cũ hơn'));
      await t.pumpAndSettle();
      expect(adapter.cursors, contains('p'));
      sync.resync();
      await t.pump(const Duration(milliseconds: 100));
      await t.pumpAndSettle();
      expect(
        adapter.cursors.where((s) => s == 'p').length,
        greaterThanOrEqualTo(2),
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('revoked recruiter form ignores late Activity lookup', (t) async {
    late GatedApi gated;
    await mount(t, () {
      gated = GatedApi(api.dio);
      return RecruitmentComposer(api: gated);
    });
    await t.tap(find.text('Nhóm tuyển thành viên'));
    await t.pumpAndSettle();
    await t.tap(find.text('R6 QA group').last);
    await t.pumpAndSettle();
    sync.accept({'type': 'SCOPE_REVOKED', 'scope': 'user:self'});
    await t.pump();
    gated.activityGate.complete([('secret', 'Private late Activity')]);
    await t.pumpAndSettle();
    expect(find.text('Private late Activity'), findsNothing);
    expect(adapter.commands, isEmpty);
    expect(t.takeException(), isNull);
  });
  testWidgets('disposed preview ignores pending successful response', (
    t,
  ) async {
    final show = ValueNotifier(true);
    addTearDown(show.dispose);
    await mount(
      t,
      () => ValueListenableBuilder(
        valueListenable: show,
        builder: (_, visible, _) => visible
            ? RecruitmentPreview(api: api, post: 'p')
            : const Scaffold(body: Text('Closed')),
      ),
    );
    adapter.gate = Completer<void>();
    sync.accept({
      'type': 'DOMAIN_CHANGED',
      'scope': 'post:p',
      'eventId': 'pending-dispose',
      'eventType': 'COMMUNITY_RECRUITMENT_CHANGED',
      'aggregateId': 'p',
    });
    await t.pump(const Duration(milliseconds: 100));
    show.value = false;
    await t.pump();
    adapter.gate!.complete();
    adapter.gate = null;
    await t.pumpAndSettle();
    expect(find.text('Closed'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  for (final status in ['EXPIRED', 'FILLED', 'CLOSED']) {
    testWidgets('$status cannot offer a new join request', (t) async {
      await mount(t, () {
        adapter.status = status;
        return RecruitmentPreview(api: api, post: 'p');
      });
      expect(find.text('Yêu cầu tham gia'), findsNothing);
      expect(adapter.joins, 0);
    });
  }
  for (final brightness in Brightness.values) {
    testWidgets(
      'narrow ${brightness.name} recruitment discovery stays within bounds',
      (t) async {
        await mount(
          t,
          () => RecruitmentDiscovery(api: api, viewer: 'viewer'),
          brightness: brightness,
          size: const Size(320, 850),
        );
        expect(t.takeException(), isNull);
        final fields = find.byType(TextField);
        final keywordBox = t.getRect(fields.at(0));
        final tagBox = t.getRect(fields.at(1));
        final locationBox = t.getRect(fields.at(2));
        expect(tagBox.top - keywordBox.bottom, greaterThanOrEqualTo(12));
        expect(locationBox.top - tagBox.bottom, greaterThanOrEqualTo(12));
      },
    );
  }
}

class GatedApi extends TestApi {
  final Completer<List<(String, String)>> activityGate = Completer();
  GatedApi(super.dio);
  @override
  Future<List<(String, String)>> activities(String group) =>
      activityGate.future;
}

class TestApi extends RecruitmentApi {
  TestApi(super.dio);
  @override
  Future<List<(String, String)>> activities(String group) async => [
    ('a', 'R6 QA Activity'),
  ];
}

class Adapter implements HttpClientAdapter {
  bool offline = false,
      denied = false,
      manager = false,
      member = false,
      pending = false,
      resolved = false,
      failCreate = false,
      paginated = false;
  String status = 'OPEN', requestState = 'NOT_REQUESTED';
  int joins = 0, approved = 0, closeCalls = 0, discoveries = 0;
  Json? created;
  Completer<void>? gate;
  final resolutions = <String>[],
      commands = <String>[],
      filters = <Json>[],
      cursors = <String>[];
  Json post([String id = 'p']) => {
    'id': id,
    'postType': 'LOOKING_FOR_MEMBERS',
    'caption': 'Tìm 3 người QA $id',
    'visibility': 'PUBLIC',
    'groupId': null,
    'author': {'id': 'owner', 'displayName': 'QA Owner'},
    'createdAt': '2026-10-27T00:00:00Z',
    'media': [],
    'reactionCount': 0,
    'myReaction': null,
    'commentCount': 0,
    'permissions': {'canEdit': false, 'canDelete': false, 'canInteract': true},
    'recruitment': {
      'groupId': 'g',
      'groupName': 'R6 QA group',
      'activityId': 'a',
      'activityTitle': 'R6 QA Activity',
      'requestedCount': 3,
      'approvedCount': approved,
      'remainingSlots': status == 'FILLED' ? 0 : 3 - approved,
      'broadLocation': 'Ba Vì',
      'tags': ['đi bộ'],
      'plannedAt': null,
      'expiresAt': '2030-01-01T00:00:00Z',
      'status': status,
      'requestState': member
          ? 'MEMBER'
          : pending
          ? 'PENDING'
          : requestState,
      'requestId': pending ? 'join' : null,
      'canRequest': status == 'OPEN' && !member && !pending,
      'canCancel': pending,
      'canManage': manager,
    },
  };
  @override
  Future<ResponseBody> fetch(
    RequestOptions r,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    if (offline) {
      throw DioException(
        requestOptions: r,
        type: DioExceptionType.connectionError,
      );
    }
    Object data = {};
    int code = 200;
    final path = r.path;
    if (path == '/api/v1/community/recruitment-options') {
      data = [
        {'groupId': 'g', 'groupName': 'R6 QA group'},
      ];
    } else if (path == '/api/v1/community/recruitments') {
      if (r.method == 'POST') {
        created = Map<String, dynamic>.from(r.data as Map);
        commands.add(created!['clientRequestId'] as String);
        data = post();
        if (failCreate) code = 503;
      } else {
        discoveries++;
        filters.add(Map<String, dynamic>.from(r.queryParameters));
        final cursor = r.queryParameters['before'] as String?;
        if (cursor != null) cursors.add(cursor);
        data = {
          'items': cursor == null ? [post()] : [post(), post('older')],
          'nextBefore': paginated && cursor == null ? 'p' : null,
          'hasMore': paginated && cursor == null,
        };
      }
    } else if (path.endsWith('/join')) {
      joins++;
      pending = true;
      data = post()['recruitment']!;
    } else if (path.endsWith('/cancel')) {
      pending = false;
      requestState = 'CANCELLED';
      data = post()['recruitment']!;
    } else if (path.endsWith('/close')) {
      closeCalls++;
      status = 'CLOSED';
      data = post()['recruitment']!;
    } else if (path.endsWith('/approve') || path.endsWith('/reject')) {
      resolutions.add(path.split('/').last);
      resolved = true;
      data = post()['recruitment']!;
    } else if (path.endsWith('/requests')) {
      data = resolved
          ? []
          : [
              {'id': 'join', 'userDisplayName': 'Outsider QA'},
            ];
      if (denied) code = 403;
    } else if (path.contains('/community/posts/')) {
      await gate?.future;
      data = post(path.split('/').last);
      if (denied) code = 403;
    }
    return ResponseBody.fromString(
      jsonEncode(data),
      code,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
