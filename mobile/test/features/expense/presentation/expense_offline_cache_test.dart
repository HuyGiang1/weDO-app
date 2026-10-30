import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/core/network/access_token_holder.dart';
import 'package:mobile/core/storage/secure_storage_service.dart';
import 'package:mobile/features/auth/application/auth_session_controller.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';
import 'package:mobile/core/realtime/realtime_binding.dart';
import 'package:mobile/core/realtime/realtime_sync.dart';
import 'package:mobile/features/chat/data/chat_realtime_client.dart';
import 'package:mobile/features/expense/application/expense_controllers.dart';
import 'package:mobile/features/expense/data/expense_api.dart';
import 'package:mobile/features/expense/data/expense_failure.dart';
import 'package:mobile/features/expense/data/expense_models.dart';
import 'package:mobile/features/expense/data/expense_repository.dart';
import 'package:mobile/features/expense/presentation/expense_screens.dart';
import 'package:mobile/features/groups/data/group_api.dart';
import 'package:mobile/features/groups/data/group_repository.dart';

import '../../auth/application/auth_session_controller_test.dart'
    show TestSecureStore, TestApi;

const network = ExpenseFailure(
  'Mất kết nối',
  apiError: ApiException(transportFailure: ApiTransportFailure.network),
);

class _RecoverySocket implements ChatRealtimeSocket {
  final frames = StreamController<dynamic>.broadcast();
  @override
  Stream<dynamic> get stream => frames.stream;
  @override
  void add(String data) {
    final frame = jsonDecode(data);
    if (frame['type'] == 'SUBSCRIBE_SCOPE') {
      frames.add(
        jsonEncode({'type': 'SCOPE_SUBSCRIBED', 'scope': frame['scope']}),
      );
    }
  }

  void pong() => frames.add(jsonEncode({'type': 'PONG'}));
  @override
  Future<void> close() => frames.close();
}

class _Repository extends ExpenseRepository {
  _Repository() : super(ExpenseApi(Dio()));
  Object? error;
  Object? balanceError;
  String revision = 'old';
  Completer<void>? gate;
  Completer<void>? balanceGate;
  int writes = 0;
  int reads = 0;
  VoidCallback? onReadSuccess;
  Future<T> read<T>(T value, {bool balance = false}) async {
    reads++;
    final failure = balance ? balanceError ?? error : error;
    final barrier = balance ? balanceGate ?? gate : gate;
    if (barrier != null) await barrier.future;
    if (failure != null) throw failure;
    onReadSuccess?.call();
    return value;
  }

  @override
  Future<List<ExpenseSummary>> list(String groupId) => read([
    ExpenseSummary.fromJson({
      'id': revision,
      'groupId': groupId,
      'title': '$groupId $revision',
      'amount': '60000.00',
      'splitMethod': 'EQUAL',
      'status': 'ACTIVE',
      'occurredAt': '2026-10-22T01:00:00Z',
      'payer': {'id': 'u', 'displayName': 'Owner'},
      'participantCount': 2,
    }),
  ]);
  @override
  Future<MyExpenseBalances> myBalances(String groupId) => read(
    MyExpenseBalances.fromJson({
      'totalOwedByMe': revision == 'old' ? '12000.00' : '15000.00',
      'totalOwedToMe': '30000.00',
      'balances': [
        {
          'user': {'id': 'u', 'displayName': 'Owner'},
          'direction': 'YOU_OWE',
          'amount': '12000.00',
        },
      ],
    }),
    balance: true,
  );
  @override
  Future<List<SettlementItem>> listSettlements(
    String groupId, {
    String? status,
    bool? involvingMe,
    String? otherUserId,
  }) => read([
    SettlementItem.fromJson({
      'id': revision,
      'groupId': groupId,
      'fromUser': {'id': 'u', 'displayName': 'Owner'},
      'toUser': {'id': 'v', 'displayName': 'Member'},
      'createdBy': {'id': 'u', 'displayName': 'Owner'},
      'amount': '12000.00',
      'status': 'PENDING',
      'declarationType': 'I_PAID',
      'createdAt': '2026-10-22T01:00:00Z',
      'updatedAt': '2026-10-22T01:00:00Z',
      'permissions': {'canConfirm': true, 'canReject': true, 'canCancel': true},
    }),
  ]);
  @override
  Future<SettlementItem> confirmSettlement(String id) async {
    writes++;
    throw StateError('Must not write from stale state');
  }
}

void main() {
  for (final settlement in [false, true]) {
    final label = settlement ? 'Settlement' : 'Expense';
    late _Repository repo;
    late dynamic controller;
    setUp(() {
      repo = _Repository();
      controller = settlement
          ? SettlementBalanceController(repo)
          : ExpenseListController(repo);
    });
    tearDown(() => controller.dispose());

    testWidgets(
      '$label aged handshake after offline resync recovers through REST auth',
      (tester) async {
        var reachable = true, expired = false, rejected = 0;
        final sockets = <_RecoverySocket>[];
        final client = WebSocketChatRealtimeClient(
          baseUrl: 'http://qa.invalid:8080',
          accessTokenProvider: () =>
              expired ? 'expired-fixture' : 'current-fixture',
          initialReconnectDelay: const Duration(milliseconds: 200),
          connector: (_, headers) async {
            if (!reachable) throw const SocketException('Offline fixture');
            if (headers['Authorization'] == 'Bearer expired-fixture') {
              rejected++;
              throw const WebSocketException('Fixture upgrade denied', 401);
            }
            final socket = _RecoverySocket();
            sockets.add(socket);
            return socket;
          },
        );
        final sync = RealtimeSync(client);
        addTearDown(() async {
          client.dispose();
          await tester.runAsync(sync.dispose);
        });
        await client.connect();
        await tester.pumpWidget(
          RealtimeHost(
            sync: sync,
            child: MaterialApp(
              home: settlement
                  ? ExpenseBalanceScreen(groupId: 'g', repository: repo)
                  : ExpenseListScreen(
                      groupId: 'g',
                      repository: repo,
                      groupRepository: GroupRepository(api: GroupApi(Dio())),
                    ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        reachable = false;
        expired = true;
        repo.error = network;
        await sockets.single.close();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Dữ liệu chưa được cập nhật.'),
          findsOneWidget,
        );
        await tester.pump(const Duration(milliseconds: 200));
        reachable = true;
        repo.error = null;
        repo.revision = 'new';
        // Models the existing REST AuthInterceptor rotating an expired token.
        repo.onReadSuccess = () => expired = false;
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 800));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        expect(rejected, 1);
        expect(sockets.length, 2);
        expect(
          find.textContaining('Dữ liệu chưa được cập nhật.'),
          findsNothing,
        );
        expect(find.text('15.000 ₫'), findsWidgets);
        expect(repo.writes, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        client.dispose();
        await tester.runAsync(sync.dispose);
        await tester.pump();
      },
    );

    testWidgets(
      '$label connected socket PONG retries transient REST once, not polling',
      (tester) async {
        final socket = _RecoverySocket();
        final client = WebSocketChatRealtimeClient(
          baseUrl: 'http://qa.invalid:8080',
          accessTokenProvider: () => 'fixture',
          connector: (_, _) async => socket,
        );
        final sync = RealtimeSync(client);
        addTearDown(() async {
          client.dispose();
          await tester.runAsync(sync.dispose);
        });
        await client.connect();
        await tester.pumpWidget(
          RealtimeHost(
            sync: sync,
            child: MaterialApp(
              home: settlement
                  ? ExpenseBalanceScreen(groupId: 'g', repository: repo)
                  : ExpenseListScreen(
                      groupId: 'g',
                      repository: repo,
                      groupRepository: GroupRepository(api: GroupApi(Dio())),
                    ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        repo.error = network;
        sync.resync();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        expect(find.text('12.000 ₫'), findsWidgets);
        final before = repo.reads;
        socket.pong();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        expect(repo.reads, before + 2);
        expect(
          find.textContaining('Dữ liệu chưa được cập nhật.'),
          findsOneWidget,
        );
        socket.pong();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        expect(
          repo.reads,
          before + 2,
          reason: 'Repeated heartbeat must not create a REST polling loop',
        );
        repo.error = null;
        repo.revision = 'new';
        // Explicit Retry remains available after the single automatic attempt failed.
        await tester.tap(find.byTooltip('Thử lại'));
        await tester.pumpAndSettle();
        expect(find.text('15.000 ₫'), findsWidgets);
        expect(
          find.textContaining('Dữ liệu chưa được cập nhật.'),
          findsNothing,
        );
        // A new invalidation arms a new bounded recovery episode.
        repo.error = network;
        sync.resync();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        repo.error = null;
        repo.revision = 'latest';
        socket.pong();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Dữ liệu chưa được cập nhật.'),
          findsNothing,
        );
        if (!settlement) expect(find.text('g latest'), findsOneWidget);
        expect(repo.writes, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        client.dispose();
        await tester.runAsync(sync.dispose);
        await tester.pump();
      },
    );

    for (final status in [401, 403]) {
      testWidgets(
        '$label PONG recovery $status clears cache and does not retry denial',
        (tester) async {
          final socket = _RecoverySocket();
          final client = WebSocketChatRealtimeClient(
            baseUrl: 'http://qa.invalid:8080',
            accessTokenProvider: () => 'fixture',
            connector: (_, _) async => socket,
          );
          final sync = RealtimeSync(client);
          addTearDown(() async {
            client.dispose();
            await tester.runAsync(sync.dispose);
          });
          await client.connect();
          await tester.pumpWidget(
            RealtimeHost(
              sync: sync,
              child: MaterialApp(
                home: settlement
                    ? ExpenseBalanceScreen(groupId: 'g', repository: repo)
                    : ExpenseListScreen(
                        groupId: 'g',
                        repository: repo,
                        groupRepository: GroupRepository(api: GroupApi(Dio())),
                      ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          repo.error = network;
          sync.resync();
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pumpAndSettle();
          repo.error = ExpenseFailure(
            'Không có quyền',
            apiError: ApiException(statusCode: status),
          );
          socket.pong();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pumpAndSettle();
          expect(find.text('12.000 ₫'), findsNothing);
          final deniedReads = repo.reads;
          socket.pong();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pumpAndSettle();
          expect(repo.reads, deniedReads);
          expect(repo.writes, 0);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          client.dispose();
          await tester.runAsync(sync.dispose);
          await tester.pump();
        },
      );
    }

    testWidgets(
      '$label real app resume resync recovers without socket replacement',
      (tester) async {
        final storage = SecureStorageService(store: TestSecureStore());
        final holder = AccessTokenHolder();
        final session = AuthSessionController(
          storage: storage,
          accessTokenHolder: holder,
          repository: AuthRepository(
            api: TestApi(),
            storage: storage,
            accessTokenHolder: holder,
          ),
          initialStatus: AuthSessionStatus.authenticated,
        );
        final sync = RealtimeSync(const NoopChatRealtimeClient());
        addTearDown(session.dispose);
        await tester.pumpWidget(
          RealtimeSession(
            sync: sync,
            session: session,
            child: MaterialApp(
              home: settlement
                  ? ExpenseBalanceScreen(groupId: 'g', repository: repo)
                  : ExpenseListScreen(
                      groupId: 'g',
                      repository: repo,
                      groupRepository: GroupRepository(api: GroupApi(Dio())),
                    ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        repo.error = network;
        sync.resync();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Dữ liệu chưa được cập nhật.'),
          findsOneWidget,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        repo.error = null;
        repo.revision = 'new';
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        expect(find.text('15.000 ₫'), findsWidgets);
        expect(
          find.textContaining('Dữ liệu chưa được cập nhật.'),
          findsNothing,
        );
        expect(repo.writes, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    test(
      '$label initial offline has no invented balances, recovers atomically',
      () async {
        repo.error = network;
        await controller.load('g');
        expect(controller.state.balances, isNull);
        expect(controller.state.loading, isFalse);
        expect(controller.state.canMutate, isFalse);
        repo.error = null;
        await controller.load('g');
        expect(controller.state.balances.totalOwedByMe.decimal, '12000.00');
        expect(controller.state.canMutate, isTrue);
      },
    );

    test(
      '$label cached snapshot remains stale through failed retry, atomic recovery',
      () async {
        await controller.load('g');
        final old = controller.state.balances;
        repo.error = network;
        await controller.load('g', silent: true);
        expect(controller.state.balances, same(old));
        expect(controller.state.stale, isTrue);
        expect(controller.state.canMutate, isFalse);
        if (settlement) {
          await controller.confirm('g', 'old');
          expect(repo.writes, 0);
          expect(controller.state.settlements.single.id, 'old');
        } else {
          expect(controller.state.expenses.single.id, 'old');
        }
        repo.error = null;
        repo.revision = 'new';
        repo.balanceGate = Completer<void>();
        final recovery = controller.load('g', silent: true);
        await Future<void>.value();
        expect(controller.state.balances, same(old));
        expect(controller.state.stale, isTrue);
        expect(controller.state.canMutate, isFalse);
        repo.balanceGate!.complete();
        await recovery;
        expect(controller.state.balances.totalOwedByMe.decimal, '15000.00');
        expect(controller.state.stale, isFalse);
        expect(controller.state.canMutate, isTrue);
        expect(
          settlement
              ? controller.state.settlements.single.id
              : controller.state.expenses.single.id,
          'new',
        );
      },
    );

    for (final lateFailure in [false, true]) {
      test(
        '$label ignores stale ${lateFailure ? 'error' : 'success'} and disposed response',
        () async {
          await controller.load('g');
          repo.gate = Completer<void>();
          repo.error = lateFailure ? network : null;
          final gate = repo.gate!;
          final old = controller.load('g');
          repo.gate = null;
          repo.error = null;
          repo.revision = 'new';
          await controller.load('g');
          gate.complete();
          await old;
          expect(controller.state.balances.totalOwedByMe.decimal, '15000.00');
          expect(controller.state.failure, isNull);
          repo.gate = Completer<void>();
          final pending = controller.load('g');
          final disposed = controller;
          controller = settlement
              ? SettlementBalanceController(repo)
              : ExpenseListController(repo);
          disposed.dispose();
          repo.gate!.complete();
          await pending;
        },
      );
    }

    for (final status in [401, 403]) {
      test(
        '$label later $status wins over the paired initial network error',
        () async {
          await controller.load('g');
          repo.gate = Completer<void>();
          repo.balanceGate = Completer<void>()..complete();
          repo.balanceError = network;
          repo.error = ExpenseFailure(
            'Không có quyền',
            apiError: ApiException(statusCode: status),
          );
          await controller.load('g');
          expect(controller.state.stale, isTrue);
          repo.gate!.complete();
          await Future<void>.delayed(Duration.zero);
          expect(controller.state.balances, isNull);
          expect(controller.state.accessDenied, isTrue);
        },
      );

      test(
        '$label $status clears data; network cannot downgrade denial',
        () async {
          await controller.load('g');
          repo.error = ExpenseFailure(
            'Không có quyền',
            apiError: ApiException(statusCode: status),
          );
          await controller.load('g');
          expect(controller.state.balances, isNull);
          expect(controller.state.accessDenied, isTrue);
          repo.error = network;
          await controller.load('g');
          expect(controller.state.accessDenied, isTrue);
          expect(controller.state.stale, isFalse);
          repo.error = null;
          await controller.load('g');
          expect(controller.state.canMutate, isTrue);
        },
      );
    }

    test(
      '$label context switch and membership loss invalidate pending reads',
      () async {
        await controller.load('g');
        repo.gate = Completer<void>();
        final pending = controller.load('g');
        final gate = repo.gate!;
        repo.gate = null;
        repo.error = network;
        await controller.load('other-group');
        expect(controller.state.balances, isNull);
        gate.complete();
        await pending;
        expect(controller.state.balances, isNull);
        repo.error = null;
        await controller.load('other-group');
        repo.gate = Completer<void>();
        final revoked = controller.load('other-group');
        controller.denyAccess();
        repo.gate!.complete();
        await revoked;
        expect(controller.state.balances, isNull);
        expect(controller.state.accessDenied, isTrue);
      },
    );

    testWidgets('$label initial offline screen shows Retry, not empty/zero', (
      tester,
    ) async {
      repo.error = network;
      await tester.pumpWidget(
        MaterialApp(
          home: settlement
              ? ExpenseBalanceScreen(groupId: 'g', repository: repo)
              : ExpenseListScreen(
                  groupId: 'g',
                  repository: repo,
                  groupRepository: GroupRepository(api: GroupApi(Dio())),
                ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.text('0 ₫'), findsNothing);
      expect(find.text('Chưa có khoản chi nào.'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      repo.error = null;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('12.000 ₫'), findsWidgets);
      final replacement = _Repository()..error = network;
      await tester.pumpWidget(
        MaterialApp(
          home: settlement
              ? ExpenseBalanceScreen(groupId: 'other', repository: replacement)
              : ExpenseListScreen(
                  groupId: 'other',
                  repository: replacement,
                  groupRepository: GroupRepository(api: GroupApi(Dio())),
                ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('12.000 ₫'), findsNothing);
      expect(find.text('g old'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '$label actual screen retains nonzero cache, disables writes and resyncs',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1000, 1600));
        final sync = RealtimeSync(const NoopChatRealtimeClient());
        addTearDown(() async {
          await sync.dispose();
          await tester.binding.setSurfaceSize(null);
        });
        final screen = settlement
            ? ExpenseBalanceScreen(groupId: 'g', repository: repo)
            : ExpenseListScreen(
                groupId: 'g',
                repository: repo,
                groupRepository: GroupRepository(api: GroupApi(Dio())),
              );
        await tester.pumpWidget(
          RealtimeHost(
            sync: sync,
            child: MaterialApp(home: screen),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('12.000 ₫'), findsWidgets);
        repo.error = network;
        sync.resync();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        expect(find.text('12.000 ₫'), findsWidgets);
        expect(
          find.textContaining('Dữ liệu chưa được cập nhật.'),
          findsOneWidget,
        );
        if (settlement) {
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Thanh toán'),
                )
                .onPressed,
            isNull,
          );
        } else {
          expect(find.text('g old'), findsOneWidget);
          expect(
            tester
                .widget<FloatingActionButton>(find.byType(FloatingActionButton))
                .onPressed,
            isNull,
          );
        }
        repo.error = null;
        repo.revision = 'new';
        sync.resync();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        expect(find.text('15.000 ₫'), findsWidgets);
        expect(
          find.textContaining('Dữ liệu chưa được cập nhật.'),
          findsNothing,
        );
        sync.accept({'type': 'SCOPE_REVOKED', 'scope': 'group:g'});
        await tester.pump();
        expect(find.text('15.000 ₫'), findsNothing);
        expect(repo.writes, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
