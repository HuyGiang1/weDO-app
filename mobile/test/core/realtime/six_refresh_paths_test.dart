import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/core/realtime/realtime_binding.dart';
import 'package:mobile/core/realtime/realtime_sync.dart';
import 'package:mobile/features/chat/data/chat_realtime_client.dart';
import 'package:mobile/features/chat/data/chat_realtime_event.dart';
import 'package:mobile/features/expense/data/expense_api.dart';
import 'package:mobile/features/expense/data/expense_repository.dart';
import 'package:mobile/features/expense/presentation/expense_screens.dart';
import 'package:mobile/features/groups/data/group_api.dart';
import 'package:mobile/features/groups/data/group_repository.dart';
import 'package:mobile/features/groups/data/models/group_models.dart';
import 'package:mobile/features/poll/data/poll_api.dart';
import 'package:mobile/features/poll/data/poll_repository.dart';
import 'package:mobile/features/poll/data/poll_models.dart';
import 'package:mobile/features/poll/presentation/screens/poll_screens.dart';
import 'package:mobile/features/task/data/task_api.dart';
import 'package:mobile/features/task/data/task_repository.dart';
import 'package:mobile/features/task/presentation/screens/task_screens.dart';

void main() {
  for (final kind in [
    'poll-list',
    'poll-detail',
    'poll-results',
    'poll-voters',
    'task-list',
    'task-detail',
    'expense',
    'settlement',
  ]) {
    late _Adapter adapter;
    late RealtimeSync sync;
    late _Client client;
    late Widget screen;
    Future<void> mount(
      WidgetTester tester, {
      bool offline = false,
      bool membersOffline = false,
    }) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1600));
      adapter = _Adapter(kind)..offline = offline;
      final dio = Dio(BaseOptions(baseUrl: 'https://fixture'))
        ..httpClientAdapter = adapter;
      final polls = PollRepository(PollApi(dio));
      final tasks = TaskRepository(TaskApi(dio));
      final finance = ExpenseRepository(ExpenseApi(dio));
      screen = switch (kind) {
        'poll-list' => PollListScreen(activityId: 'a', repository: polls),
        'poll-detail' => PollDetailScreen(pollId: 'p', repository: polls),
        'poll-results' => PollResultsScreen(
          poll: Poll.fromJson(adapter._json(1)), repository: polls,
        ),
        'poll-voters' => PollVotersScreen(
          poll: Poll.fromJson(adapter._json(1)), repository: polls,
        ),
        'task-list' => TaskListScreen(
          activityId: 'a',
          repository: tasks,
          loadMembers: () async => [],
        ),
        'task-detail' => TaskDetailScreen(
          taskId: 't',
          repository: tasks,
          loadMembers: () async {
            if (membersOffline) {
              throw const ApiException(
                transportFailure: ApiTransportFailure.network,
              );
            }
            return [GroupMember(userId: 'u', username: 'qa',
              displayName: 'QA Member ${adapter.version}', role: GroupRole.member,
              joinedAt: DateTime.utc(2026))];
          },
        ),
        'expense' => ExpenseDetailScreen(
          groupId: 'g',
          expenseId: 'e',
          repository: finance,
          groupRepository: GroupRepository(api: GroupApi(dio)),
        ),
        _ => SettlementDetailScreen(
          groupId: 'g',
          settlementId: 's',
          repository: finance,
        ),
      };
      client = _Client();
      sync = RealtimeSync(client);
      await tester.pumpWidget(
        RealtimeHost(
          sync: sync,
          child: MaterialApp(home: screen),
        ),
      );
      await tester.pumpAndSettle();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(sync.dispose);
        await client.frames.close();
        await tester.binding.setSurfaceSize(null);
      });
    }

    String getScope() =>
        kind == 'expense' || kind == 'settlement' ? 'group:g' : 'activity:a';
    Future<void> control(WidgetTester tester, String type) async {
      sync.accept({'type': type, 'scope': getScope()});
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
    }

    dynamic state(WidgetTester tester) => tester.state(
      kind == 'poll-results' || kind == 'poll-voters'
          ? find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_LivePoll')
          : find.byWidget(screen),
    );
    Finder label(int version) => find.textContaining('QA resource $version');

    if (kind.startsWith('poll') || kind.startsWith('task')) {
      testWidgets('$kind duplicate domain hints refetch once and update current UI', (tester) async {
        await mount(tester);
        final before = adapter.calls;
        adapter.version = 2;
        final frame = {'type': 'DOMAIN_CHANGED', 'eventId': 'one',
          'eventType': kind.startsWith('poll') ? 'POLL_VOTE_CHANGED' : 'TASK_STATUS_CHANGED',
          'aggregateId': kind.startsWith('poll') ? 'p' : 't', 'scope': getScope()};
        sync.accept(frame);
        sync.accept(frame);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        expect(label(2), findsWidgets);
        expect(adapter.calls - before, kind == 'poll-voters' || kind == 'poll-results' ? 2 : 1);
        expect(adapter.writes, 0);
      });
      if (kind != 'poll-voters') {
        testWidgets('$kind remote close or completion updates visible lifecycle state', (tester) async {
          await mount(tester);
          adapter.closed = true;
          sync.accept({'type': 'DOMAIN_CHANGED', 'eventId': 'lifecycle',
            'eventType': kind.startsWith('poll') ? 'POLL_CLOSED' : 'TASK_STATUS_CHANGED',
            'aggregateId': kind.startsWith('poll') ? 'p' : 't', 'scope': getScope()});
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pumpAndSettle();
          expect(find.text(kind.startsWith('task') ? 'Hoàn thành' :
            kind == 'poll-list' ? 'Đã đóng' : 'Bình chọn đã đóng'), findsWidgets);
          if (kind == 'poll-detail') expect(find.text('Gửi bình chọn'), findsNothing);
        });
      }
      testWidgets('$kind connected PONG has one bounded transient-read recovery', (tester) async {
        await mount(tester);
        adapter.offline = true;
        await control(tester, 'SCOPE_RESYNC');
        final failedCalls = adapter.calls;
        client.pong();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        expect(adapter.calls, failedCalls + 1);
        for (var i = 0; i < 3; i++) { client.pong(); await tester.pump(const Duration(seconds: 1)); }
        expect(adapter.calls, failedCalls + 1);
        adapter.offline = false;
        adapter.version = 2;
        await control(tester, 'SCOPE_SUBSCRIBED');
        expect(label(2), findsWidgets);
        final healthyCalls = adapter.calls;
        client.pong(); await tester.pump(const Duration(seconds: 1));
        expect(adapter.calls, healthyCalls);
      });
    }

    if (kind == 'poll-voters') {
      testWidgets('anonymous Poll never requests voter identities after resync', (tester) async {
        await mount(tester);
        adapter.anonymous = true;
        final before = adapter.voterCalls;
        await control(tester, 'SCOPE_RESYNC');
        expect(find.text('Bình chọn này ẩn danh.'), findsOneWidget);
        expect(adapter.voterCalls, before);
        expect(label(1), findsNothing);
      });
    }

    if (kind == 'task-detail') {
      testWidgets('task-detail refreshes assigned member names after resync', (tester) async {
        await mount(tester);
        expect(find.text('QA Member 1'), findsOneWidget);
        adapter.version = 2;
        await control(tester, 'SCOPE_RESYNC');
        expect(find.text('QA Member 2'), findsOneWidget);
        expect(find.text('QA Member 1'), findsNothing);
      });
      testWidgets(
        'task-detail auxiliary member-name network failure is handled',
        (tester) async {
          await mount(tester, membersOffline: true);
          expect(tester.takeException(), isNull);
          expect(label(1), findsWidgets);
        },
      );
    }

    testWidgets(
      '$kind transient error preserves data; authorized reconnect recovers without uncaught error',
      (tester) async {
        await mount(tester);
        expect(label(1), findsWidgets);
        adapter.offline = true;
        await control(tester, 'SCOPE_RESYNC');
        expect(tester.takeException(), isNull);
        expect(label(1), findsWidgets);
        expect(
          find.textContaining('Dữ liệu chưa được cập nhật'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<AbsorbPointer>(
                find
                    .ancestor(
                      of: label(1).first,
                      matching: find.byType(AbsorbPointer),
                    )
                    .first,
              )
              .absorbing,
          isTrue,
        );
        adapter.offline = false;
        adapter.version = 2;
        await control(tester, 'SCOPE_SUBSCRIBED');
        expect(label(2), findsWidgets);
        expect(label(1), findsNothing);
        expect(find.textContaining('Dữ liệu chưa được cập nhật'), findsNothing);
        final calls = adapter.calls;
        await tester.pump(const Duration(seconds: 10));
        expect(adapter.calls, calls);
        expect(adapter.writes, 0);
      },
    );
    testWidgets(
      '$kind initial offline is retry, not false empty or perpetual spinner',
      (tester) async {
        await mount(tester, offline: true);
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Không thể kết nối'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.textContaining('Chưa có'), findsNothing);
        adapter.offline = false;
        await tester.tap(find.textContaining('Không thể kết nối'));
        await tester.pumpAndSettle();
        expect(label(1), findsWidgets);
      },
    );
    testWidgets(
      '$kind malformed authoritative response is reported, not hidden as connectivity',
      (tester) async {
        await mount(tester);
        adapter.malformed = true;
        await control(tester, 'SCOPE_RESYNC');
        expect(
          tester.takeException(),
          anyOf(isA<FormatException>(), isA<TypeError>()),
        );
        expect(find.textContaining('Không thể kết nối'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );
    for (final status in [401, 403, 404]) {
      testWidgets(
        '$kind $status removes cached content, never a network success',
        (tester) async {
          await mount(tester);
          adapter.status = status;
          await control(tester, 'SCOPE_RESYNC');
          expect(tester.takeException(), isNull);
          expect(label(1), findsNothing);
          expect(
            find.textContaining(status == 401 ? 'đăng nhập' : 'quyền'),
            findsOneWidget,
          );
          expect(
            find.textContaining('Dữ liệu chưa được cập nhật'),
            findsNothing,
          );
        final deniedCalls = adapter.calls;
        client.pong();
        await tester.pump(const Duration(seconds: 1));
        expect(adapter.calls, deniedCalls);
        },
      );
    }
    testWidgets(
      '$kind scope revocation clears content immediately even with failed REST',
      (tester) async {
        await mount(tester);
        adapter.offline = true;
        sync.accept({'type': 'SCOPE_REVOKED', 'scope': getScope()});
        await tester.pump();
        expect(label(1), findsNothing);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        expect(label(1), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
    for (final fail in [false, true]) {
      testWidgets(
        '$kind late ${fail ? 'failed' : 'successful'} read cannot replace new data; dispose ignores pending read',
        (tester) async {
          await mount(tester);
          final gate = Completer<void>();
          adapter.gate = gate;
          adapter.offline = fail;
          final Future<void> old = state(tester).reloadRealtime();
          await tester
              .pump(); // Adapter captured this request's gate and state.
          adapter.gate = null;
          adapter.offline = false;
          adapter.version = 2;
          final Future<void> newer = state(tester).reloadRealtime();
          await tester.pumpAndSettle();
          await newer;
          gate.complete();
          await tester.pumpAndSettle();
          await old;
          await tester.pumpAndSettle();
          expect(label(2), findsWidgets);
          expect(
            find.textContaining('Dữ liệu chưa được cập nhật'),
            findsNothing,
          );
          final disposed = Completer<void>();
          adapter.gate = disposed;
          adapter.offline = fail;
          final Future<void> pending = state(tester).reloadRealtime();
          await tester.pump();
          await tester.pumpWidget(const SizedBox());
          disposed.complete();
          await tester.pumpAndSettle();
          await pending;
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

class _Adapter implements HttpClientAdapter {
  final String kind;
  _Adapter(this.kind);
  int version = 1, status = 200, calls = 0, writes = 0, voterCalls = 0;
  bool offline = false, malformed = false, anonymous = false, closed = false;
  Completer<void>? gate;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    calls++;
    if (options.path.endsWith('/voters')) voterCalls++;
    if (options.method != 'GET') writes++;
    final fail = offline, code = status, data = _json(version);
    final waiting = gate;
    if (waiting != null) await waiting.future;
    if (fail) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    final body = code != 200
        ? {'code': 'ACCESS_DENIED'}
        : malformed
        ? <String, dynamic>{}
        : options.path.endsWith('/voters')
        ? [{'optionId': 'o', 'userIds': ['u']}]
        : kind.endsWith('-list')
        ? [data]
        : data;
    return ResponseBody.fromString(
      jsonEncode(body),
      code,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  Map<String, dynamic> _json(int version) => {
    'id': kind.startsWith('poll')
        ? 'p'
        : kind.startsWith('task')
        ? 't'
        : kind == 'expense'
        ? 'e'
        : 's',
    'activityId': 'a',
    'groupId': 'g',
    'createdBy': kind == 'settlement'
        ? {'id': 'u', 'displayName': 'Creator'}
        : 'u',
    'question': 'QA resource $version',
    'title': 'QA resource $version',
    'status': kind.startsWith('poll')
        ? (closed ? 'CLOSED' : 'OPEN')
        : kind.startsWith('task')
        ? (closed ? 'DONE' : 'TODO')
        : kind == 'expense'
        ? 'ACTIVE'
        : 'PENDING',
    'pollType': 'SINGLE_CHOICE',
    'voteVisibility': anonymous ? 'ANONYMOUS' : 'PUBLIC',
    'resultVisibility': 'IMMEDIATE',
    'resultsVisible': true,
    'options': kind.startsWith('poll') ? [
      {'id': 'o', 'text': 'QA resource $version', 'sortOrder': 0,
       'disabled': false, 'createdBy': 'u', 'voteCount': version},
    ] : <Object>[],
    'callerOptionIds': <Object>[],
    'assigneeUserIds': kind == 'task-detail' ? ['u'] : <Object>[],
    'statusHistory': <Object>[],
    'amount': '10.01',
    'splitMethod': 'EQUAL',
    'participantCount': 1,
    'occurredAt': '2026-10-21T10:00:00Z',
    'createdAt': '2026-10-21T10:00:00Z',
    'updatedAt': '2026-10-21T10:00:00Z',
    'payer': {'id': 'u', 'displayName': 'Payer'},
    'creator': {'id': 'u', 'displayName': 'Creator'},
    'shares': <Object>[],
    'changeHistory': <Object>[],
    'fromUser': {'id': 'u', 'displayName': 'QA resource $version'},
    'toUser': {'id': 'v', 'displayName': 'Receiver'},
    'declarationType': 'I_PAID',
    'permissions': {'canConfirm': true, 'canEdit': true, 'canCancel': true,
      'canVote': !closed && kind.startsWith('poll'), 'canViewVoters': !anonymous},
  };
  @override
  void close({bool force = false}) {}
}

class _Client extends NoopChatRealtimeClient {
  final frames = StreamController<ChatRealtimeEvent>.broadcast();
  @override
  Stream<ChatRealtimeEvent> get events => frames.stream;
  void pong() => frames.add(const ChatRealtimeEvent(type: ChatRealtimeEventType.pong, rawType: 'PONG'));
}
