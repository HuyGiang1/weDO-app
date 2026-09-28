import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/expense/data/expense_api.dart';
import 'package:mobile/core/utils/date_time_formatter.dart';
import 'package:mobile/features/expense/application/expense_controllers.dart';
import 'package:mobile/features/expense/data/expense_failure.dart';
import 'package:mobile/features/expense/data/expense_models.dart';
import 'package:mobile/features/expense/data/expense_repository.dart';
import 'package:mobile/features/expense/presentation/expense_screens.dart';
import 'package:mobile/features/groups/data/group_api.dart';
import 'package:mobile/features/groups/data/group_repository.dart';

void main() {
  testWidgets('cancelling reloads detail without an async setState callback', (
    tester,
  ) async {
    final adapter = _ExpenseAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://test'))
      ..httpClientAdapter = adapter;
    final repository = ExpenseRepository(ExpenseApi(dio));
    final groupRepository = GroupRepository(api: GroupApi(dio));

    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseDetailScreen(
          groupId: 'group-1',
          expenseId: 'expense-1',
          repository: repository,
          groupRepository: groupRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Hủy khoản chi').first);
    await tester.tap(find.text('Hủy khoản chi').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Hủy khoản chi'));
    await tester.pumpAndSettle();

    expect(adapter.cancelRequested, isTrue);
    expect(find.textContaining('Đã hủy'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  for (final flags in [(true, false), (false, true), (false, false)]) {
    testWidgets(
      'detail independently respects edit=${flags.$1} cancel=${flags.$2}',
      (tester) async {
        final adapter = _ExpenseAdapter()
          ..canEdit = flags.$1
          ..canCancel = flags.$2;
        await _detail(tester, adapter);
        expect(
          find.text('Chỉnh sửa khoản chi'),
          flags.$1 ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Hủy khoản chi'),
          flags.$2 ? findsOneWidget : findsNothing,
        );
        expect(find.text('Payer'), findsOneWidget);
        expect(find.text('Member'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'history localizes states and times without displaying reference IDs',
    (tester) async {
      final adapter = _ExpenseAdapter()..cancelRequested = true;
      await _detail(tester, adapter);
      await tester.scrollUntilVisible(find.text('Người thanh toán').last, 150);
      expect(find.textContaining('ACTIVE'), findsNothing);
      expect(find.textContaining('CANCELLED'), findsNothing);
      expect(find.textContaining('old-internal-id'), findsNothing);
      expect(
        find.textContaining('Đang tính vào số dư → Đã hủy'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          AppDateTimeFormatter.formatDateTime(
            DateTime.parse('2026-09-28T10:00:00Z'),
          ),
        ),
        findsWidgets,
      );
      expect(find.text('Hủy khoản chi'), findsNothing);
    },
  );

  testWidgets(
    'list loads, shows empty state, retries a server denial and shows data',
    (tester) async {
      final adapter = _ExpenseAdapter()
        ..empty = true
        ..gate = Completer<void>();
      final dio = _dio(adapter);
      await tester.pumpWidget(
        MaterialApp(
          home: ExpenseListScreen(
            groupId: 'group-1',
            repository: ExpenseRepository(ExpenseApi(dio)),
            groupRepository: GroupRepository(api: GroupApi(dio)),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      adapter.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Chưa có khoản chi nào.'), findsOneWidget);
      adapter.failureCode = 'ACCESS_DENIED';
      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(
        find.text('Bạn không có quyền xem dữ liệu nhóm này.'),
        findsOneWidget,
      );
      adapter.failureCode = null;
      adapter.empty = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Dinner'), findsOneWidget);
      expect(adapter.paths, contains('/api/v1/groups/group-1/expenses'));
    },
  );

  testWidgets(
    'create selects participant and sends exact amount and group ID',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final adapter = _ExpenseAdapter()..empty = true;
      final dio = _dio(adapter);
      await tester.pumpWidget(
        MaterialApp(
          home: ExpenseListScreen(
            groupId: 'group-1',
            repository: ExpenseRepository(ExpenseApi(dio)),
            groupRepository: GroupRepository(api: GroupApi(dio)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thêm khoản chi'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tên khoản chi'),
        'Dinner',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Số tiền'),
        '10.01',
      );
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Member'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Lưu khoản chi'));
      await tester.tap(find.text('Lưu khoản chi'));
      await tester.pumpAndSettle();
      expect(adapter.mutationPath, '/api/v1/groups/group-1/expenses');
      expect(adapter.draft?['amount'], '10.01');
      expect(adapter.draft?['participantUserIds'], ['member-1']);
      expect(adapter.draft?['payerUserId'], 'payer-1');
      expect(adapter.draft?['occurredAt'], endsWith('Z'));
      expect(adapter.memberLoads, 1);
      expect(find.text('Dinner'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'custom edit retains allocation and activity and rejects a mismatched total',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final adapter = _ExpenseAdapter();
      final dio = _dio(adapter);
      final initial = ExpenseDetail.fromJson({
        ..._expenseJson(cancelled: false),
        'splitMethod': 'CUSTOM_AMOUNT',
        'activityId': 'activity-1',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: ExpenseFormScreen(
            groupId: 'group-1',
            initial: initial,
            repository: ExpenseRepository(ExpenseApi(dio)),
            groupRepository: GroupRepository(api: GroupApi(dio)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final shareField = find.widgetWithText(TextField, 'Phần của Member');
      expect(tester.widget<TextField>(shareField).controller!.text, '10.00');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Số tiền'),
        '12.00',
      );
      await tester.ensureVisible(find.text('Lưu khoản chi'));
      await tester.tap(find.text('Lưu khoản chi'));
      await tester.pumpAndSettle();
      expect(
        find.text('Tổng phần chia phải bằng tổng khoản chi.'),
        findsOneWidget,
      );
      expect(adapter.draft, isNull);
      await tester.enterText(shareField, '12.00');
      await tester.ensureVisible(find.text('Lưu khoản chi'));
      await tester.tap(find.text('Lưu khoản chi'));
      await tester.pumpAndSettle();
      expect(adapter.mutationPath, '/api/v1/expenses/expense-1');
      expect(adapter.draft?['activityId'], 'activity-1');
      expect(adapter.draft?['shares'], [
        {'userId': 'member-1', 'amount': '12.00'},
      ]);
      expect(adapter.memberLoads, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('balances display server directions and no settlement action', (
    tester,
  ) async {
    final adapter = _ExpenseAdapter();
    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseBalanceScreen(
          groupId: 'group-1',
          repository: ExpenseRepository(ExpenseApi(_dio(adapter))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bạn đang nợ'), findsWidgets);
    expect(find.text('Bạn được nhận'), findsWidgets);
    expect(find.text('10,01 ₫'), findsWidgets);
    expect(find.text('Payer'), findsOneWidget);
    expect(find.text('Thanh toán'), findsNothing);
  });

  test('repository maps API failure to Vietnamese', () async {
    final adapter = _ExpenseAdapter()..failureCode = 'ACCESS_DENIED';
    await expectLater(
      ExpenseRepository(ExpenseApi(_dio(adapter))).list('group-1'),
      throwsA(
        isA<ExpenseFailure>().having(
          (e) => e.message,
          'message',
          'Bạn không có quyền xem dữ liệu nhóm này.',
        ),
      ),
    );
  });

  test(
    'list completion after dispose does not notify a disposed controller',
    () async {
      final adapter = _ExpenseAdapter()..gate = Completer<void>();
      final controller = ExpenseListController(
        ExpenseRepository(ExpenseApi(_dio(adapter))),
      );
      final loading = controller.load('group-1');
      controller.dispose();
      adapter.gate!.complete();
      await loading;
    },
  );
}

Dio _dio(_ExpenseAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'https://test'))..httpClientAdapter = adapter;

Future<void> _detail(WidgetTester tester, _ExpenseAdapter adapter) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final dio = _dio(adapter);
  await tester.pumpWidget(
    MaterialApp(
      home: ExpenseDetailScreen(
        groupId: 'group-1',
        expenseId: 'expense-1',
        repository: ExpenseRepository(ExpenseApi(dio)),
        groupRepository: GroupRepository(api: GroupApi(dio)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _ExpenseAdapter implements HttpClientAdapter {
  bool cancelRequested = false;
  bool canEdit = true, canCancel = true, empty = false;
  String? failureCode, mutationPath;
  Completer<void>? gate;
  Map<String, dynamic>? draft;
  final List<String> paths = [];
  int memberLoads = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (gate != null) await gate!.future;
    paths.add(options.path);
    Object response;
    var status = 200;
    if (failureCode != null) {
      status = 403;
      response = {'code': failureCode};
    } else if (options.path.endsWith('/members')) {
      memberLoads++;
      response = [
        for (final member in [('payer-1', 'Payer'), ('member-1', 'Member')])
          {
            'userId': member.$1,
            'username': member.$2,
            'displayName': member.$2,
            'role': 'MEMBER',
            'joinedAt': '2026-09-28T10:00:00Z',
          },
      ];
    } else if (options.path.endsWith('/balances/me')) {
      response = {
        'totalOwedByMe': '10.01',
        'totalOwedToMe': '0.00',
        'balances': [
          {
            'user': {'id': 'payer-1', 'displayName': 'Payer'},
            'direction': 'YOU_OWE',
            'amount': '10.01',
          },
        ],
      };
    } else {
      if (options.path.endsWith('/cancel')) cancelRequested = true;
      if (options.data is Map) {
        draft = Map<String, dynamic>.from(options.data as Map);
        mutationPath = options.path;
        empty = false;
      }
      final detail = {
        ..._expenseJson(cancelled: cancelRequested),
        'permissions': {'canEdit': canEdit, 'canCancel': canCancel},
      };
      response = options.method == 'GET' && options.path.endsWith('/expenses')
          ? (empty
                ? []
                : [
                    {...detail, 'participantCount': 1},
                  ])
          : detail;
    }
    return ResponseBody.fromString(
      jsonEncode(response),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _expenseJson({required bool cancelled}) => {
  'id': 'expense-1',
  'groupId': 'group-1',
  'title': 'Dinner',
  'amount': '10.00',
  'splitMethod': 'EQUAL',
  'status': cancelled ? 'CANCELLED' : 'ACTIVE',
  'occurredAt': '2026-09-28T10:00:00Z',
  'payer': {'id': 'payer-1', 'displayName': 'Payer'},
  'creator': {'id': 'creator-1', 'displayName': 'Creator'},
  'permissions': {'canEdit': true, 'canCancel': true},
  'shares': [
    {'userId': 'member-1', 'displayName': 'Member', 'amount': '10.00'},
  ],
  'changeHistory': cancelled
      ? [
          {
            'fieldName': 'status',
            'oldValue': 'ACTIVE',
            'newValue': 'CANCELLED',
            'createdAt': '2026-09-28T10:00:00Z',
          },
          {
            'fieldName': 'payerUserId',
            'oldValue': 'old-internal-id',
            'newValue': 'payer-1',
            'createdAt': '2026-09-28T10:00:00Z',
          },
        ]
      : [],
  'createdAt': '2026-09-28T10:00:00Z',
  'updatedAt': '2026-09-28T10:00:00Z',
};
