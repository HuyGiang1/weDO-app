import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/realtime/realtime_binding.dart';
import 'package:mobile/core/realtime/realtime_sync.dart';
import 'package:mobile/features/chat/data/chat_realtime_client.dart';
import 'package:mobile/features/community/data/moderation_api.dart';
import 'package:mobile/features/community/presentation/moderation_screen.dart';

Map<String, dynamic> item({String state = 'ACTIVE'}) => {
  'id': 'report',
  'targetType': 'POST',
  'targetId': 'post',
  'postId': 'post',
  'reason': 'SPAM',
  'status': state == 'REMOVED' ? 'REVIEWED' : 'OPEN',
  'createdAt': '2026-10-27T00:00:00Z',
  'evidence': 'QA evidence',
  'contentStatus': state,
  'allowedActions': state == 'REMOVED'
      ? ['RESTORE']
      : ['REMOVE', 'DISMISS', 'RESOLVE'],
};

class Adapter implements HttpClientAdapter {
  bool moderator = true,
      denied = false,
      offline = false,
      blocked = true,
      hidden = true;
  String content = 'ACTIVE';
  final writes = <RequestOptions>[];
  final reads = <RequestOptions>[];
  final commands = <String>[];
  Completer<void>? gate;
  int history = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions r,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    reads.add(r);
    int status = 200;
    dynamic data = <String, dynamic>{};
    if (r.path == '/api/v1/me') {
      data = {'id': 'viewer'};
    } else if (r.path == '/api/v1/moderation/access') {
      data = {'canReview': moderator, 'globalModerator': moderator};
    } else if (r.path == '/api/v1/moderation/reports') {
      data = {
        'items': [item(state: content)],
        'nextBefore': null,
        'hasMore': false,
      };
      await gate?.future;
      if (denied || !moderator) {
        status = 403;
      } else if (offline) {
        status = 503;
      }
    } else if (r.path.endsWith('/actions')) {
      writes.add(r);
      commands.add(r.data['clientRequestId'] as String);
      content = r.data['action'] == 'REMOVE' ? 'REMOVED' : 'ACTIVE';
      history++;
      data = {
        'report': item(state: content),
        'history': [
          {
            'id': 'audit',
            'moderatorId': 'viewer',
            'action': r.data['action'],
            'reason': r.data['reason'],
            'createdAt': '2026-10-27T00:00:00Z',
          },
        ],
      };
      await gate?.future;
      if (denied) status = 403;
    } else if (r.path == '/api/v1/moderation/reports/report') {
      data = {
        'report': item(state: content),
        'history': history == 0
            ? []
            : [
                {
                  'id': 'audit',
                  'moderatorId': 'viewer',
                  'action': 'REMOVE',
                  'reason': 'QA reason',
                  'createdAt': '2026-10-27T00:00:00Z',
                },
              ],
      };
      await gate?.future;
      if (denied) {
        status = 403;
      } else if (offline) {
        status = 503;
      }
    } else if (r.path == '/api/v1/me/blocked-users') {
      data = {
        'items': blocked
            ? [
                {
                  'id': 'block',
                  'blockedUser': {'id': 'author', 'displayName': 'Blocked QA'},
                },
              ]
            : [],
        'hasNext': false,
      };
    } else if (r.path.endsWith('/block')) {
      writes.add(r);
      blocked = r.method != 'DELETE';
    } else if (r.path == '/api/v1/community/hidden-posts') {
      data = {
        'items': hidden
            ? [
                {'id': 'post', 'caption': 'Hidden QA'},
              ]
            : [],
        'hasMore': false,
        'nextBefore': null,
      };
    } else if (r.path.endsWith('/hidden')) {
      writes.add(r);
      hidden = false;
    } else if (r.path.endsWith('/reports')) {
      writes.add(r);
    } else {
      writes.add(r);
    }
    return ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Adapter adapter;
  late ModerationApi api;
  late RealtimeSync sync;
  Future<void> mount(
    WidgetTester t,
    Widget Function() screen, {
    bool moderator = true,
    Size size = const Size(500, 950),
    Brightness brightness = Brightness.light,
  }) async {
    adapter = Adapter()..moderator = moderator;
    api = ModerationApi(
      Dio(BaseOptions(baseUrl: 'https://fixture'))..httpClientAdapter = adapter,
    );
    sync = RealtimeSync(const NoopChatRealtimeClient());
    await t.binding.setSurfaceSize(size);
    await t.pumpWidget(
      RealtimeHost(
        sync: sync,
        child: MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: screen(),
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

  Future<void> resync(WidgetTester t) async {
    sync.accept({'type': 'SCOPE_RESYNC', 'scope': 'moderation:viewer'});
    await t.pump(const Duration(milliseconds: 100));
    await t.pumpAndSettle();
  }

  testWidgets(
    'ordinary user has privacy controls but no moderator navigation',
    (t) async {
      await mount(t, () => CommunitySafetyScreen(api: api), moderator: false);
      expect(find.text('Người đã chặn'), findsOneWidget);
      expect(find.text('Duyệt báo cáo'), findsNothing);
      expect(adapter.writes, isEmpty);
    },
  );
  testWidgets('global moderator opens authorized queue', (t) async {
    await mount(t, () => CommunitySafetyScreen(api: api));
    await t.tap(find.text('Duyệt báo cáo'));
    await t.pumpAndSettle();
    expect(find.text('QA evidence'), findsOneWidget);
  });
  testWidgets('queue filters are sent to REST', (t) async {
    await mount(t, () => ModerationQueue(api: api, viewer: 'viewer'));
    await t.tap(find.text('Chờ xử lý'));
    await t.pumpAndSettle();
    await t.tap(find.text('Đã bác bỏ').last);
    await t.pumpAndSettle();
    expect(adapter.reads.last.queryParameters['status'], 'DISMISSED');
  });
  testWidgets('remove and restore require reason and render audit', (t) async {
    await mount(
      t,
      () => ModerationReview(api: api, viewer: 'viewer', id: 'report'),
    );
    await t.tap(find.text('Gỡ nội dung'));
    await t.pumpAndSettle();
    expect(adapter.writes, isEmpty);
    await t.enterText(find.byType(TextField), 'QA reason');
    await t.tap(find.text('Gỡ nội dung'));
    await t.pumpAndSettle();
    expect(find.text('Nội dung đã gỡ'), findsOneWidget);
    expect(adapter.history, 1);
    expect(adapter.commands.single, isNotEmpty);
    await t.enterText(find.byType(TextField), 'Restore QA');
    await t.tap(find.text('Khôi phục nội dung'));
    await t.pumpAndSettle();
    expect(adapter.content, 'ACTIVE');
  });
  testWidgets('blocked users list unblocks through existing API', (t) async {
    await mount(t, () => SafetyPersonalList(api: api, blocked: true));
    expect(find.text('Blocked QA'), findsOneWidget);
    await t.tap(find.text('Bỏ chặn'));
    await t.pumpAndSettle();
    expect(find.text('Blocked QA'), findsNothing);
    expect(adapter.writes.single.path, '/api/v1/users/author/block');
    expect(adapter.writes.single.method, 'DELETE');
  });
  testWidgets('hidden posts can be restored only through unhide', (t) async {
    await mount(t, () => SafetyPersonalList(api: api, blocked: false));
    await t.tap(find.text('Hiện lại'));
    await t.pumpAndSettle();
    expect(find.text('Hidden QA'), findsNothing);
    expect(adapter.writes.single.path, '/api/v1/community/posts/post/hidden');
  });
  testWidgets('permission denial clears evidence and hides actions', (t) async {
    await mount(
      t,
      () => ModerationReview(api: api, viewer: 'viewer', id: 'report'),
    );
    adapter.denied = true;
    await resync(t);
    expect(find.text('QA evidence'), findsNothing);
    expect(find.text('Gỡ nội dung'), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'offline resync clears permission-sensitive evidence and reconnect refetches',
    (t) async {
      await mount(
        t,
        () => ModerationReview(api: api, viewer: 'viewer', id: 'report'),
      );
      adapter.offline = true;
      await resync(t);
      expect(find.text('QA evidence'), findsNothing);
      expect(find.text('Gỡ nội dung'), findsNothing);
      expect(t.takeException(), isNull);
      adapter.offline = false;
      adapter.content = 'REMOVED';
      await resync(t);
      expect(find.text('QA evidence'), findsOneWidget);
      expect(find.text('Nội dung đã gỡ'), findsOneWidget);
      expect(adapter.writes, isEmpty);
    },
  );
  testWidgets(
    'resync clears protected cache before delayed read; stale disposed reply ignored',
    (t) async {
      await mount(
        t,
        () => ModerationReview(api: api, viewer: 'viewer', id: 'report'),
      );
      adapter.gate = Completer<void>();
      sync.accept({'type': 'SCOPE_RESYNC', 'scope': 'moderation:viewer'});
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('QA evidence'), findsNothing);
      await t.pumpWidget(const SizedBox());
      adapter.gate!.complete();
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'scope revoked prevents late command result resurrecting evidence',
    (t) async {
      await mount(
        t,
        () => ModerationReview(api: api, viewer: 'viewer', id: 'report'),
      );
      await t.enterText(find.byType(TextField), 'QA reason');
      adapter.gate = Completer<void>();
      await t.tap(find.text('Gỡ nội dung'));
      await t.pump();
      sync.accept({'type': 'SCOPE_REVOKED', 'scope': 'moderation:viewer'});
      adapter.denied = true;
      adapter.gate!.complete();
      await t.pumpAndSettle();
      expect(find.text('QA evidence'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('direct moderator route denies ordinary user', (t) async {
    await mount(
      t,
      () => ModerationQueue(api: api, viewer: 'viewer'),
      moderator: false,
    );
    expect(find.text('QA evidence'), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('report reasons use required taxonomy', (t) async {
    await mount(
      t,
      () => Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => chooseReportReason(context),
            child: const Text('Report'),
          ),
        ),
      ),
    );
    await t.tap(find.text('Report'));
    await t.pumpAndSettle();
    expect(find.text('Lừa đảo'), findsOneWidget);
    expect(find.text('Nội dung không phù hợp'), findsOneWidget);
  });
  testWidgets(
    'report user and comment use correct targets without public queue reads',
    (t) async {
      await mount(t, () => const SizedBox());
      await t.runAsync(() async {
        await api.reportUser('u', 'SCAM');
        await api.reportComment('c', 'SPAM');
      });
      expect(adapter.writes.map((r) => r.path), [
        '/api/v1/users/u/reports',
        '/api/v1/community/comments/c/reports',
      ]);
      expect(adapter.writes.first.data['reason'], 'SCAM');
    },
  );
  for (final brightness in Brightness.values) {
    testWidgets('narrow review supports ${brightness.name}', (t) async {
      await mount(
        t,
        () => ModerationReview(api: api, viewer: 'viewer', id: 'report'),
        size: const Size(320, 900),
        brightness: brightness,
      );
      expect(t.takeException(), isNull);
    });
  }
}
