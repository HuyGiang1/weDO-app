import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/fund/data/fund_api.dart';
import 'package:mobile/features/fund/data/fund_failure.dart';
import 'package:mobile/features/fund/data/fund_models.dart';
import 'package:mobile/features/fund/data/fund_repository.dart';
import 'package:mobile/features/fund/presentation/fund_screens.dart';
import 'package:mobile/features/groups/application/group_detail_controller.dart';
import 'package:mobile/features/groups/data/group_api.dart';
import 'package:mobile/features/groups/data/group_repository.dart';
import 'package:mobile/features/groups/data/models/group_models.dart';
import 'package:mobile/features/groups/presentation/screens/group_info_screen.dart';

class _FakeFundApi extends FundApi {
  FundDetail? fund;
  final List<FundCollectionSummary> collections = [];
  FundCollectionDetail? collectionDetail;
  final List<FundExpenseItem> expenses = [];
  final List<FundReimbursementItem> reimbursements = [];
  final List<FundTransactionItem> transactions = [];

  _FakeFundApi() : super(Dio());

  @override
  Future<FundDetail> getGroupFund(String groupId) async {
    if (fund == null) {
      throw const ApiException(
        code: 'FUND_NOT_FOUND',
        message: 'Group fund was not found.',
        statusCode: 404,
      );
    }
    return fund!;
  }

  @override
  Future<FundDetail> createFund(String groupId, {String? name}) async {
    fund = FundDetail(
      fundId: 'fund-1',
      groupId: groupId,
      name: (name?.trim().isNotEmpty == true) ? name!.trim() : 'Quỹ nhóm',
      status: 'ACTIVE',
      ledgerBalance: ExpenseMoney.fromJson('200000.00'),
      pendingReimbursements: ExpenseMoney.fromJson('50000.00'),
      availableBalance: ExpenseMoney.fromJson('150000.00'),
      totalInflow: ExpenseMoney.fromJson('200000.00'),
      totalOutflow: ExpenseMoney.fromJson('0.00'),
      permissions: const FundPermissionProjection(
        isOwner: true,
        isFundManager: true,
        canManageFund: true,
        canManageManagers: true,
        canCloseFund: false,
        canCreateCollection: true,
        canRecordExpense: true,
        canRequestReimbursement: true,
        canSubmitContribution: true,
      ),
      createdBy: const FundUserSummary(
        userId: 'u-owner',
        displayName: 'Trưởng nhóm',
      ),
      createdAt: DateTime(2026, 9, 28),
      updatedAt: DateTime(2026, 9, 28),
    );
    return fund!;
  }

  @override
  Future<List<FundCollectionSummary>> listCollections(
    String fundId, {
    String? status,
  }) async => collections;

  @override
  Future<List<FundExpenseItem>> listFundExpenses(String fundId) async =>
      expenses;

  @override
  Future<List<FundReimbursementItem>> listReimbursements(
    String fundId, {
    String? status,
  }) async => reimbursements;

  @override
  Future<List<FundTransactionItem>> listTransactions(
    String fundId, {
    String? type,
    String? direction,
  }) async => transactions;

  @override
  Future<FundCollectionDetail> createCollection(
    String fundId, {
    required String title,
    String? description,
    DateTime? deadlineAt,
    String allocationMode = 'EQUAL_PER_MEMBER',
    String? amountPerMember,
    List<String>? targetUserIds,
    List<Map<String, dynamic>>? obligations,
  }) async {
    final amount = ExpenseMoney.fromJson(amountPerMember ?? '100000.00');
    final summary = FundCollectionSummary(
      collectionId: 'col-1',
      fundId: fundId,
      title: title,
      description: description,
      status: 'OPEN',
      totalExpectedAmount: amount,
      totalConfirmedAmount: ExpenseMoney.zero,
      totalPendingAmount: ExpenseMoney.zero,
      totalRemainingAmount: amount,
      totalMembersCount: 1,
      paidMembersCount: 0,
      pendingContributionsCount: 0,
      myAmountDue: amount,
      myConfirmedAmount: ExpenseMoney.zero,
      myPendingAmount: ExpenseMoney.zero,
      myRemainingAmount: amount,
      myObligationStatus: 'UNPAID',
      createdBy: const FundUserSummary(
        userId: 'u-owner',
        displayName: 'Trưởng nhóm',
      ),
      createdAt: DateTime(2026, 9, 28),
    );
    collections.insert(0, summary);
    collectionDetail = FundCollectionDetail(
      collectionId: 'col-1',
      fundId: fundId,
      title: title,
      description: description,
      status: 'OPEN',
      totalExpectedAmount: amount,
      totalConfirmedAmount: ExpenseMoney.zero,
      totalPendingAmount: ExpenseMoney.zero,
      totalRemainingAmount: amount,
      totalMembersCount: 1,
      paidMembersCount: 0,
      pendingContributionsCount: 0,
      obligations: [
        CollectionObligationItem(
          obligationId: 'ob-1',
          collectionId: 'col-1',
          user: const FundUserSummary(
            userId: 'u-member',
            displayName: 'Thành viên A',
          ),
          amountDue: amount,
          confirmedAmount: ExpenseMoney.zero,
          pendingAmount: ExpenseMoney.zero,
          remainingAmount: amount,
          status: 'UNPAID',
          createdAt: DateTime(2026, 9, 28),
        ),
      ],
      contributions: const [],
      createdBy: const FundUserSummary(
        userId: 'u-owner',
        displayName: 'Trưởng nhóm',
      ),
      createdAt: DateTime(2026, 9, 28),
      canManageCollection: true,
      canContribute: true,
    );
    return collectionDetail!;
  }

  @override
  Future<FundCollectionDetail> getCollectionDetail(String collectionId) async =>
      collectionDetail!;

  @override
  Future<FundExpenseItem> createFundExpense(
    String fundId, {
    required String title,
    required String amount,
    DateTime? occurredAt,
    String? activityId,
    String? receiptStorageKey,
    String? note,
  }) async {
    final item = FundExpenseItem(
      expenseId: 'exp-1',
      fundId: fundId,
      title: title,
      amount: ExpenseMoney.fromJson(amount),
      occurredAt: DateTime(2026, 9, 28),
      note: note,
      transactionId: 'tx-exp-1',
      createdBy: const FundUserSummary(
        userId: 'u-owner',
        displayName: 'Trưởng nhóm',
      ),
      createdAt: DateTime(2026, 9, 28),
    );
    expenses.insert(0, item);
    transactions.insert(
      0,
      FundTransactionItem(
        transactionId: 'tx-exp-1',
        fundId: fundId,
        transactionType: 'FUND_EXPENSE',
        direction: 'OUT',
        amount: ExpenseMoney.fromJson(amount),
        referenceType: 'FUND_EXPENSE',
        referenceId: 'exp-1',
        referenceTitle: 'Chi trực tiếp từ quỹ',
        note: note ?? title,
        createdBy: const FundUserSummary(
          userId: 'u-owner',
          displayName: 'Trưởng nhóm',
        ),
        createdAt: DateTime(2026, 9, 28),
        canReverse: true,
      ),
    );
    return item;
  }

  @override
  Future<FundReimbursementItem> createReimbursement(
    String fundId, {
    required String amount,
    required String reason,
    String? receiptStorageKey,
  }) async {
    final item = FundReimbursementItem(
      reimbursementId: 'reimb-1',
      fundId: fundId,
      user: const FundUserSummary(
        userId: 'u-member',
        displayName: 'Thành viên A',
      ),
      amount: ExpenseMoney.fromJson(amount),
      reason: reason,
      status: 'PENDING',
      createdAt: DateTime(2026, 9, 28),
      canApprove: true,
      canReject: true,
      canCancel: true,
    );
    reimbursements.insert(0, item);
    return item;
  }

  @override
  Future<FundReimbursementItem> approveReimbursement(
    String reimbursementId,
  ) async {
    final old = reimbursements.first;
    final approved = FundReimbursementItem(
      reimbursementId: old.reimbursementId,
      fundId: old.fundId,
      user: old.user,
      amount: old.amount,
      reason: old.reason,
      status: 'COMPLETED',
      createdAt: old.createdAt,
      transactionId: 'tx-reimb-1',
    );
    reimbursements[0] = approved;
    return approved;
  }

  @override
  Future<FundTransactionItem> reverseTransaction(
    String transactionId, {
    required String reason,
  }) async {
    final reversal = FundTransactionItem(
      transactionId: 'tx-rev-1',
      fundId: 'fund-1',
      transactionType: 'REVERSAL',
      direction: 'IN',
      amount: ExpenseMoney.fromJson('50000.00'),
      referenceTitle: 'Giao dịch đảo bút toán',
      note: reason,
      createdBy: const FundUserSummary(
        userId: 'u-owner',
        displayName: 'Trưởng nhóm',
      ),
      createdAt: DateTime(2026, 9, 28),
      originalTransactionId: transactionId,
      canReverse: false,
    );
    transactions.insert(0, reversal);
    return reversal;
  }
}

class _FakeGroupRepository extends GroupRepository {
  _FakeGroupRepository() : super(api: GroupApi(Dio()));

  @override
  Future<GroupDetail> getGroup(String id) async => GroupDetail(
    id: id,
    name: 'Nhóm Du Lịch',
    status: GroupStatus.active,
    ownerUserId: 'u-owner',
    callerRole: GroupRole.owner,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  @override
  Future<List<GroupMember>> getMembers(String id) async => [
    GroupMember(
      userId: 'u-owner',
      username: 'owner',
      displayName: 'Trưởng nhóm',
      role: GroupRole.owner,
      joinedAt: DateTime(2026, 1, 1),
    ),
  ];
}

void main() {
  group('M13 Fund Models & Failure Mapping', () {
    test('parses FundDetail, obligations, and maps localized error codes', () {
      final ob = CollectionObligationItem.fromJson({
        'obligationId': 'ob-1',
        'collectionId': 'col-1',
        'user': {
          'userId': 'u-former',
          'displayName': 'Minh',
          'activeMember': false,
        },
        'amountDue': '150000.00',
        'confirmedAmount': '50000.00',
        'pendingAmount': '0.00',
        'remainingAmount': '100000.00',
        'status': 'PARTIAL',
        'createdAt': '2026-09-28T10:00:00Z',
      });
      expect(ob.statusLabel, 'Đóng một phần');
      expect(ob.user.displayLabel, 'Minh (Cựu thành viên)');

      final failure = FundFailure.fromError(
        const ApiException(
          code: 'FUND_INSUFFICIENT_BALANCE',
          message: 'Insufficient available fund balance.',
          statusCode: 409,
        ),
      );
      expect(
        failure.message,
        'Số dư khả dụng của quỹ không đủ để thực hiện giao dịch này.',
      );
    });
  });

  group('M13 GroupFundScreen & GroupInfoScreen Widget Tests', () {
    testWidgets(
      'creates group fund from empty state and executes collection, expense, reimbursement, and reversal flows',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeApi = _FakeFundApi();
        final repo = FundRepository(fakeApi);

        await tester.pumpWidget(
          MaterialApp(
            home: GroupFundScreen(
              groupId: 'g-1',
              groupName: 'Nhóm Đà Lạt',
              repository: repo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initially shows empty state
        expect(find.text('Nhóm chưa có quỹ chung'), findsOneWidget);
        await tester.tap(find.byKey(const Key('create-group-fund-btn')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('create-fund-name-input')),
          'Quỹ Đà Lạt 2026',
        );
        await tester.tap(find.byKey(const Key('confirm-create-fund-btn')));
        await tester.pumpAndSettle();

        // Hero balance card rendered
        expect(find.text('Quỹ Đà Lạt 2026'), findsOneWidget);
        expect(find.text('150.000 ₫'), findsOneWidget);
        expect(find.text('200.000 ₫'), findsWidgets);

        // Create collection
        await tester.tap(find.byKey(const Key('open-create-collection-btn')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('collection-title-input')),
          'Thu quỹ đợt 1',
        );
        await tester.enterText(
          find.byKey(const Key('collection-amount-input')),
          '100000',
        );
        await tester.tap(
          find.byKey(const Key('confirm-create-collection-btn')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Thu quỹ đợt 1'), findsOneWidget);

        // Create direct fund expense
        await tester.tap(find.byKey(const Key('open-create-fund-expense-btn')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('fund-expense-title-input')),
          'Mua nước uống',
        );
        await tester.enterText(
          find.byKey(const Key('fund-expense-amount-input')),
          '50000',
        );
        await tester.tap(
          find.byKey(const Key('confirm-create-fund-expense-btn')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Mua nước uống'), findsOneWidget);

        // Create & approve reimbursement
        await tester.tap(
          find.byKey(const Key('open-create-reimbursement-btn')),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('reimbursement-reason-input')),
          'Ứng tiền mua bánh',
        );
        await tester.enterText(
          find.byKey(const Key('reimbursement-amount-input')),
          '30000',
        );
        await tester.tap(
          find.byKey(const Key('confirm-create-reimbursement-btn')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Ứng tiền mua bánh'), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const Key('approve-reimbursement-reimb-1')),
        );
        await tester.tap(
          find.byKey(const Key('approve-reimbursement-reimb-1')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Đã hoàn ứng'), findsOneWidget);

        // Switch to Transactions tab and reverse expense transaction
        await tester.ensureVisible(
          find.byKey(const Key('fund-tab-transactions')),
        );
        await tester.tap(find.byKey(const Key('fund-tab-transactions')));
        await tester.pumpAndSettle();
        expect(find.text('Chi trực tiếp từ quỹ'), findsOneWidget);
        await tester.ensureVisible(find.byKey(const Key('reverse-tx-tx-exp-1')));
        await tester.tap(find.byKey(const Key('reverse-tx-tx-exp-1')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('reverse-transaction-reason-input')),
          'Nhập nhầm số tiền',
        );
        await tester.tap(
          find.byKey(const Key('confirm-reverse-transaction-btn')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Giao dịch đảo bút toán'), findsOneWidget);
      },
    );

    testWidgets(
      'GroupInfoScreen exposes Chi tiêu, Thanh toán công nợ, and Quỹ nhóm distinctly',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        bool fundTapped = false;
        final controller = GroupDetailController(_FakeGroupRepository());

        await tester.pumpWidget(
          MaterialApp(
            home: GroupInfoScreen(
              groupId: 'g-1',
              controller: controller,
              onEdit: () {},
              onMembers: () {},
              onSettings: () {},
              onActivityLog: () {},
              onLeave: () {},
              onExpenses: () {},
              onSettlements: () {},
              onFund: () => fundTapped = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Chi tiêu'), findsOneWidget);
        expect(find.text('Thanh toán công nợ'), findsOneWidget);
        expect(find.text('Quỹ nhóm'), findsOneWidget);

        await tester.ensureVisible(find.text('Quỹ nhóm'));
        await tester.tap(find.text('Quỹ nhóm'));
        await tester.pumpAndSettle();
        expect(fundTapped, isTrue);
      },
    );
  });
}
