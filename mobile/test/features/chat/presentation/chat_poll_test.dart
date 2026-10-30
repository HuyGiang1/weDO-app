import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/realtime/realtime_binding.dart';
import 'package:mobile/core/realtime/realtime_sync.dart';
import 'package:mobile/features/chat/data/chat_realtime_client.dart';
import 'package:mobile/features/chat/data/chat_api.dart';
import 'package:mobile/features/chat/data/chat_models.dart';
import 'package:mobile/features/chat/presentation/chat_poll_create_screen.dart';
import 'package:mobile/features/chat/presentation/chat_poll_card.dart';
import 'package:mobile/features/poll/data/poll_api.dart';
import 'package:mobile/features/poll/data/poll_repository.dart';
import 'package:mobile/features/poll/presentation/screens/poll_screens.dart';

void main() {
  for (final groupOnly in [false, true]) {
    testWidgets(
      'Chat create optional Activity=$groupOnly returns durable Poll message once',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1000, 1600));
      final adapter = _CreateAdapter()..noActivities = groupOnly..activityFailure = groupOnly;
        final api = ChatApi(
          Dio(BaseOptions(baseUrl: 'https://fixture'))
            ..httpClientAdapter = adapter,
        );
        ChatMessage? result;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await Navigator.of(context).push<ChatMessage>(
                      MaterialPageRoute(
                        builder: (_) => ChatPollCreateScreen(
                          conversationId: 'c',
                          groupId: 'g',
                          api: api,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(groupOnly ? 'Chỉ trong nhóm' : 'Real Activity'),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).at(0), 'Question');
        await tester.enterText(find.byType(TextField).at(1), 'A');
        await tester.enterText(find.byType(TextField).at(2), 'B');
        await tester.tap(find.widgetWithText(FilledButton, 'Tạo bình chọn'));
        await tester.pumpAndSettle();
        expect(adapter.posts, 1);
        expect(result?.type, 'POLL');
        expect(result?.pollId, 'p');
        expect(adapter.sent?['activityId'], groupOnly ? null : 'a');
        expect(
          adapter.sent?['clientMessageId'],
          matches(RegExp(r'^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$')),
        );
        expect(adapter.sent?['poll']['options'], ['A', 'B']);
        await tester.pumpWidget(const SizedBox());
        await tester.binding.setSurfaceSize(null);
      },
    );
  }
  late _Adapter adapter;
  late PollRepository repository;
  late RealtimeSync sync;
  Future<void> mount(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    adapter = _Adapter();
    repository = PollRepository(
      PollApi(
        Dio(BaseOptions(baseUrl: 'https://fixture'))
          ..httpClientAdapter = adapter,
      ),
    );
    sync = RealtimeSync(const NoopChatRealtimeClient());
    await tester.pumpWidget(
      RealtimeHost(
        sync: sync,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChatPollCard(pollId: 'p', repository: repository),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(sync.dispose);
      await tester.binding.setSurfaceSize(null);
    });
  }

  Future<void> hint(
    WidgetTester tester, {
    String id = 'change',
    String type = 'DOMAIN_CHANGED',
  }) async {
    sync.accept({
      'type': type,
      'eventId': id,
      'eventType': 'POLL_VOTE_CHANGED',
      'scope': 'activity:a',
      'aggregateId': 'p',
    });
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  Future<void> vote(WidgetTester tester, String option) async {
    await tester.tap(find.text(option));
    await tester.pump();
    await tester.tap(find.text(adapter.ballot.isEmpty ? 'Bình chọn' : 'Đổi bình chọn'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'card first vote and replacement use authoritative totals, no double count',
    (tester) async {
      await mount(tester);
      await vote(tester, 'A');
      expect(find.text('1 phiếu'), findsOneWidget);
      await vote(tester, 'B');
      expect(adapter.ballot, ['b']);
      expect(adapter.votes, 2);
      expect(find.text('1 phiếu'), findsOneWidget);
      expect(find.text('1 người đã bình chọn'), findsOneWidget);
      expect(adapter.history, 0);
    },
  );
  testWidgets(
    'multiple choice, anonymous and hidden results follow server projection',
    (tester) async {
      await mount(tester);
      adapter.multiple = true;
      adapter.anonymous = true;
      adapter.hidden = true;
      await hint(tester);
      await tester.tap(find.text('A'));
      await tester.pump();
      await tester.tap(find.text('B'));
      await tester.pump();
      await tester.tap(find.text('Bình chọn'));
      await tester.pumpAndSettle();
      expect(adapter.ballot.toSet(), {'a', 'b'});
      expect(find.text('Bình chọn ẩn danh'), findsOneWidget);
      expect(find.text('Kết quả chưa được hiển thị.'), findsOneWidget);
      expect(find.textContaining('phiếu'), findsNothing);
      expect(adapter.voters, 0);
    },
  );
  testWidgets(
    'remote hint/dedupe and reconnect resync update card, not conversation',
    (tester) async {
      await mount(tester);
      adapter.version = 2;
      await hint(tester);
      final reads = adapter.reads;
      await hint(tester);
      expect(adapter.reads, reads);
      expect(find.text('Decision 2'), findsOneWidget);
      adapter.version = 3;
      await hint(tester, type: 'SCOPE_SUBSCRIBED');
      expect(find.text('Decision 3'), findsOneWidget);
      expect(adapter.history, 0);
    },
  );
  testWidgets('closed backend state disables vote and survives resync', (
    tester,
  ) async {
    await mount(tester);
    adapter.closed = true;
    await hint(tester);
    expect(find.text('Bình chọn đã đóng'), findsOneWidget);
    expect(find.text('Bình chọn'), findsNothing);
    expect(
      tester
          .widget<CheckboxListTile>(find.byType(CheckboxListTile).first)
          .onChanged,
      isNull,
    );
  });
  testWidgets(
    'group-only Poll card and group history route group hints and revocation',
    (tester) async {
      await mount(tester);
      adapter.groupOnly = true;
      await hint(
        tester,
      ); // Authoritative response rebinds from Activity to Group.
      adapter.version = 2;
      sync.accept({
        'type': 'DOMAIN_CHANGED',
        'eventId': 'group-vote',
        'eventType': 'POLL_VOTE_CHANGED',
        'scope': 'group:g',
        'aggregateId': 'p',
        'groupId': 'g',
      });
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.text('Decision 2'), findsOneWidget);
      await tester.pumpWidget(
        RealtimeHost(
          sync: sync,
          child: MaterialApp(
            home: PollListScreen.group(groupId: 'g', repository: repository),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Decision 2'), findsOneWidget);
      adapter.offline = true;
      sync.accept({'type': 'SCOPE_REVOKED', 'scope': 'group:g'});
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.text('Decision 2'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'close action uses canonical endpoint and authoritative closed response',
    (tester) async {
      await mount(tester);
      await tester.tap(find.text('Đóng bình chọn'));
      await tester.pumpAndSettle();
      expect(adapter.closed, isTrue);
      expect(find.text('Bình chọn đã đóng'), findsOneWidget);
    },
  );
  testWidgets(
    'transient error preserves data, then reconnect obtains current data',
    (tester) async {
      await mount(tester);
      adapter.offline = true;
      await hint(tester);
      expect(find.text('Decision 1'), findsOneWidget);
      expect(find.textContaining('Dữ liệu chưa'), findsOneWidget);
      expect(tester.takeException(), isNull);
      adapter.offline = false;
      adapter.version = 2;
      await hint(tester, type: 'SCOPE_SUBSCRIBED');
      expect(find.text('Decision 2'), findsOneWidget);
      expect(find.textContaining('Dữ liệu chưa'), findsNothing);
    },
  );
  for (final status in [401, 403, 404]) {
    testWidgets('card $status clears protected content', (tester) async {
      await mount(tester);
      adapter.status = status;
      await hint(tester);
      expect(find.text('Decision 1'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'scope loss clears cached content immediately even when offline',
    (tester) async {
      await mount(tester);
      adapter.offline = true;
      await hint(tester, type: 'SCOPE_REVOKED');
      expect(find.text('Decision 1'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'old response cannot overwrite new result; disposed response is ignored',
    (tester) async {
      await mount(tester);
      final oldGate = Completer<void>();
      adapter.gate = oldGate;
      final dynamic state = tester.state(find.byType(ChatPollCard));
      final Future<void> old = state.reloadRealtime();
      await tester.pump();
      adapter.gate = null;
      adapter.version = 2;
      final Future<void> next = state.reloadRealtime();
      await tester.pumpAndSettle();
      await next;
      oldGate.complete();
      await tester.pumpAndSettle();
      await old;
      expect(find.text('Decision 2'), findsOneWidget);
      final disposed = Completer<void>();
      adapter.gate = disposed;
      final Future<void> pending = state.reloadRealtime();
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      disposed.complete();
      await tester.pumpAndSettle();
      await pending;
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('overlapping vote submits once and late dispose is safe', (
    tester,
  ) async {
    await mount(tester);
    adapter.voteGate = Completer<void>();
    await tester.tap(find.text('A'));
    await tester.pump();
    await tester.tap(find.text('Bình chọn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đang gửi…'));
    await tester.pumpAndSettle();
    expect(adapter.votes, 1);
    await tester.pumpWidget(const SizedBox());
    adapter.voteGate!.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  for (final brightness in Brightness.values) {
    testWidgets('compact narrow card supports $brightness without overflow', (tester) async {
      await mount(tester);
      await tester.binding.setSurfaceSize(const Size(280, 900));
      await tester.pumpWidget(RealtimeHost(sync: sync, child: MaterialApp(theme: ThemeData(brightness: brightness),
        home: Scaffold(body: SingleChildScrollView(child: ChatPollCard(pollId:'p', repository:repository))))));
      await tester.pumpAndSettle();
      expect(find.text('BÌNH CHỌN'), findsOneWidget);
      expect(tester.getSize(find.byType(ChatPollCard)).width, lessThanOrEqualTo(280));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('participant preview opens names and multi-choice option membership', (tester) async {
    await mount(tester);
    await vote(tester, 'A');
    expect(find.text('1 người đã bình chọn'), findsOneWidget);
    await tester.tap(find.text('1 người đã bình chọn'));
    await tester.pumpAndSettle();
    expect(find.text('Người đã bình chọn'), findsOneWidget);
    expect(find.text('QA Member'), findsWidgets);
    expect(find.text('member'), findsNothing);
    expect(adapter.voters, 1);
  });

  testWidgets('uncertain vote retry keeps command identity; changed selection gets new command', (tester) async {
    await mount(tester);
    adapter.offline = true;
    await vote(tester, 'A');
    adapter.offline = false;
    await tester.tap(find.text('Bình chọn'));
    await tester.pumpAndSettle();
    expect(adapter.commands, hasLength(2));
    expect(adapter.commands[0], adapter.commands[1]);
    await vote(tester, 'B');
    expect(adapter.commands.last, isNot(adapter.commands.first));
  });

  testWidgets(
    'create form validates before authoritative create; offers existing multiple choice',
    (tester) async {
      await mount(tester);
      var submitted = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CreatePollScreen(
            activityId: 'a',
            repository: repository,
            allowMultipleChoiceControl: true,
            onCreate: (draft) async {
              submitted++;
              expect(draft.options.length, 2);
            },
          ),
        ),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Tạo bình chọn'));
      await tester.pumpAndSettle();
      expect(submitted, 0);
      expect(
        find.text('Nhập câu hỏi và ít nhất hai lựa chọn.'),
        findsOneWidget,
      );
      expect(find.text('Cho phép chọn nhiều đáp án'), findsOneWidget);
    },
  );
}

class _Adapter implements HttpClientAdapter {
  final commands = <String>[];
  int reads = 0, votes = 0, history = 0, voters = 0, version = 1, status = 200;
  bool offline = false,
      closed = false,
      multiple = false,
      anonymous = false,
      hidden = false,
      groupOnly = false;
  List<String> ballot = [];
  Completer<void>? gate, voteGate;
  Map<String, dynamic> data() => {
    'id': 'p',
    'activityId': groupOnly ? null : 'a',
    'groupId': 'g',
    'createdBy': 'owner',
    'question': 'Decision $version',
    'pollType': multiple ? 'MULTIPLE_CHOICE' : 'SINGLE_CHOICE',
    'voteVisibility': anonymous ? 'ANONYMOUS' : 'PUBLIC',
    'resultVisibility': hidden ? 'AFTER_CLOSE' : 'IMMEDIATE',
    'resultsVisible': !hidden || closed,
    'status': closed ? 'CLOSED' : 'OPEN',
    'callerOptionIds': List.of(ballot),
    'participantCount': ballot.isEmpty ? 0 : 1,
    'participantPreview': anonymous || hidden || ballot.isEmpty ? [] : [{'id':'member','displayName':'QA Member','avatarStorageKey':null}],
    'options': [
      for (final id in ['a', 'b'])
        {
          'id': id,
          'text': id.toUpperCase(),
          'sortOrder': id == 'a' ? 0 : 1,
          'disabled': false,
          'createdBy': 'owner',
          'voteCount': hidden && !closed
              ? 0
              : ballot.contains(id)
              ? 1
              : 0,
        },
    ],
    'permissions': {'canVote': !closed, 'canClose': !closed, 'canViewVoters': !anonymous && !hidden},
  };
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    if (request.path.contains('/messages')) history++;
    if (request.path.endsWith('/voters')) voters++;
    if (request.method == 'PUT') {
      commands.add(request.data['clientRequestId'] as String);
      votes++;
      if (voteGate != null) await voteGate!.future;
      ballot = List<String>.from(request.data['optionIds']);
    }
    if (request.path.endsWith('/close')) closed = true;
    if (request.method == 'GET') reads++;
    final snapshot = data();
    final waiting = gate;
    final fail = offline;
    final code = status;
    if (waiting != null) await waiting.future;
    if (fail) {
      throw DioException(
        requestOptions: request,
        type: DioExceptionType.connectionError,
      );
    }
    return ResponseBody.fromString(
      jsonEncode(
        code == 200
            ? (request.path.endsWith('/voters') ? [for(final id in ['a','b']) {'optionId':id,'userIds':ballot.contains(id)?['member']:[], 'participants':ballot.contains(id)?[{'id':'member','displayName':'QA Member','avatarStorageKey':null}]:[]}] : request.path == '/api/v1/groups/g/polls' ? [snapshot] : snapshot)
            : {'code': 'ACCESS_DENIED'},
      ),
      code,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _CreateAdapter implements HttpClientAdapter {
  int posts = 0;
  Map<String, dynamic>? sent;
  bool noActivities = false;
  bool activityFailure = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions r,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    Object data;
    if (r.method == 'POST') {
      posts++;
      sent = Map<String, dynamic>.from(r.data);
      data = {
        'id': sent!['clientMessageId'],
        'pollId': 'p',
        'type': 'POLL',
        'status': 'ACTIVE',
        'sequence': 1,
        'isMine': true,
        'content': 'Question',
        'createdAt': '2026-10-25T10:00:00Z',
        'permissions': {},
      };
    } else {
      data = {
        'items': noActivities
            ? []
            : [
                {
                  'id': 'a',
                  'title': 'Real Activity',
                  'status': 'PLANNING',
                  'goingCount': 0,
                  'waitlistCount': 0,
                  'callerRsvpStatus': 'NO_RESPONSE',
                },
              ],
        'page': 0,
        'size': 30,
        'totalElements': 1,
        'totalPages': 1,
        'hasNext': false,
      };
    }
    return ResponseBody.fromString(
      jsonEncode(r.method == 'GET' && activityFailure ? {'code':'UNAVAILABLE'} : data),
      r.method == 'GET' && activityFailure ? 503 : r.method == 'POST' ? 201 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
