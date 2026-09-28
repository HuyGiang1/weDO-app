import 'package:flutter/foundation.dart';

import '../data/fund_failure.dart';
import '../data/fund_models.dart';
import '../data/fund_repository.dart';

class GroupFundState {
  final bool loading;
  final bool submitting;
  final bool notCreatedYet;
  final FundDetail? fund;
  final List<FundCollectionSummary> collections;
  final List<FundExpenseItem> expenses;
  final List<FundReimbursementItem> reimbursements;
  final List<FundTransactionItem> transactions;
  final FundCollectionDetail? activeCollectionDetail;
  final FundFailure? failure;

  const GroupFundState({
    this.loading = false,
    this.submitting = false,
    this.notCreatedYet = false,
    this.fund,
    this.collections = const [],
    this.expenses = const [],
    this.reimbursements = const [],
    this.transactions = const [],
    this.activeCollectionDetail,
    this.failure,
  });

  GroupFundState copyWith({
    bool? loading,
    bool? submitting,
    bool? notCreatedYet,
    FundDetail? fund,
    List<FundCollectionSummary>? collections,
    List<FundExpenseItem>? expenses,
    List<FundReimbursementItem>? reimbursements,
    List<FundTransactionItem>? transactions,
    FundCollectionDetail? activeCollectionDetail,
    FundFailure? failure,
    bool clearFailure = false,
  }) => GroupFundState(
    loading: loading ?? this.loading,
    submitting: submitting ?? this.submitting,
    notCreatedYet: notCreatedYet ?? this.notCreatedYet,
    fund: fund ?? this.fund,
    collections: collections ?? this.collections,
    expenses: expenses ?? this.expenses,
    reimbursements: reimbursements ?? this.reimbursements,
    transactions: transactions ?? this.transactions,
    activeCollectionDetail:
        activeCollectionDetail ?? this.activeCollectionDetail,
    failure: clearFailure ? null : (failure ?? this.failure),
  );
}

class GroupFundController extends ValueNotifier<GroupFundState> {
  final FundRepository repository;

  GroupFundController(this.repository) : super(const GroupFundState());

  Future<void> load(String groupId) async {
    value = value.copyWith(loading: true, clearFailure: true);
    try {
      final fund = await repository.getGroupFund(groupId);
      await _loadFundWorkspace(fund);
    } on FundFailure catch (failure) {
      if (failure.isNotFound) {
        value = const GroupFundState(
          loading: false,
          notCreatedYet: true,
        );
      } else {
        value = value.copyWith(loading: false, failure: failure);
      }
    } catch (error) {
      value = value.copyWith(
        loading: false,
        failure: FundFailure.fromError(error),
      );
    }
  }

  Future<void> _loadFundWorkspace(FundDetail fund) async {
    final results = await Future.wait<dynamic>([
      repository.listCollections(fund.fundId),
      repository.listFundExpenses(fund.fundId),
      repository.listReimbursements(fund.fundId),
      repository.listTransactions(fund.fundId),
    ]);
    value = GroupFundState(
      loading: false,
      submitting: false,
      notCreatedYet: false,
      fund: fund,
      collections: results[0] as List<FundCollectionSummary>,
      expenses: results[1] as List<FundExpenseItem>,
      reimbursements: results[2] as List<FundReimbursementItem>,
      transactions: results[3] as List<FundTransactionItem>,
      activeCollectionDetail: value.activeCollectionDetail,
    );
  }

  Future<bool> createFund(String groupId, {String? name}) async {
    value = value.copyWith(submitting: true, clearFailure: true);
    try {
      final created = await repository.createFund(groupId, name: name);
      await _loadFundWorkspace(created);
      return true;
    } catch (error) {
      value = value.copyWith(
        submitting: false,
        failure: FundFailure.fromError(error),
      );
      return false;
    }
  }

  Future<bool> closeFund(String groupId, String fundId) async {
    value = value.copyWith(submitting: true, clearFailure: true);
    try {
      await repository.closeFund(fundId);
      await load(groupId);
      return true;
    } catch (error) {
      value = value.copyWith(
        submitting: false,
        failure: FundFailure.fromError(error),
      );
      return false;
    }
  }

  Future<bool> assignManager(String groupId, String fundId, String userId) async {
    value = value.copyWith(submitting: true, clearFailure: true);
    try {
      await repository.assignManager(fundId, userId);
      await load(groupId);
      return true;
    } catch (error) {
      value = value.copyWith(
        submitting: false,
        failure: FundFailure.fromError(error),
      );
      return false;
    }
  }

  Future<bool> revokeManager(String groupId, String fundId, String userId) async {
    value = value.copyWith(submitting: true, clearFailure: true);
    try {
      await repository.revokeManager(fundId, userId);
      await load(groupId);
      return true;
    } catch (error) {
      value = value.copyWith(
        submitting: false,
        failure: FundFailure.fromError(error),
      );
      return false;
    }
  }

  Future<FundCollectionDetail?> loadCollectionDetail(String collectionId) async {
    try {
      final detail = await repository.getCollectionDetail(collectionId);
      value = value.copyWith(
        activeCollectionDetail: detail,
        clearFailure: true,
      );
      return detail;
    } catch (error) {
      value = value.copyWith(failure: FundFailure.fromError(error));
      return null;
    }
  }

  Future<bool> createCollection(
    String groupId,
    String fundId, {
    required String title,
    String? description,
    DateTime? deadlineAt,
    String allocationMode = 'EQUAL_PER_MEMBER',
    String? amountPerMember,
    List<String>? targetUserIds,
    List<Map<String, dynamic>>? obligations,
  }) async {
    value = value.copyWith(submitting: true, clearFailure: true);
    try {
      final detail = await repository.createCollection(
        fundId,
        title: title,
        description: description,
        deadlineAt: deadlineAt,
        allocationMode: allocationMode,
        amountPerMember: amountPerMember,
        targetUserIds: targetUserIds,
        obligations: obligations,
      );
      value = value.copyWith(activeCollectionDetail: detail);
      await load(groupId);
      return true;
    } catch (error) {
      value = value.copyWith(
        submitting: false,
        failure: FundFailure.fromError(error),
      );
      return false;
    }
  }

  Future<bool> closeCollection(String groupId, String collectionId) async {
    value = value.copyWith(submitting: true, clearFailure: true);
    try {
      final detail = await repository.closeCollection(collectionId);
      value = value.copyWith(activeCollectionDetail: detail);
      await load(groupId);
      return true;
    } catch (error) {
      value = value.copyWith(
        submitting: false,
        failure: FundFailure.fromError(error),
      );
      return false;
    }
  }

  Future<bool> cancelCollection(String groupId, String collectionId) async {
    value = value.copyWith(submitting: true, clearFailure: true);
    try {
      final detail = await repository.cancelCollection(collectionId);
      value = value.copyWith(activeCollectionDetail: detail);
      await load(groupId);
      return true;
    } catch (error) {
      value = value.copyWith(
        submitting: false,
        failure: FundFailure.fromError(error),
      );
      return false;
    }
  }

  Future<bool> submitContribution(
    String groupId,
    String collectionId, {
    required String amount,
    String? userId,
    String? proofStorageKey,
    String? note,
  }) async {
    value = value.copyWith(submitting: true, clearFailure: true);
    try {
      await repository.submitContribution(
        collectionId,
        amount: amount,
        userId: userId,
        proofStorageKey: proofStorageKey,
        note: note,
      );
      await loadCollectionDetail(collectionId);
      await load(groupId);
      return true;
    } catch (error) {
      value = value.copyWith(
        submitting: false,
        failure: FundFailure.fromError(error),
      );
      return false;
    }
  }

  Future<bool> confirmContribution(
    String groupId,
    String collectionId,
    String contributionId,
  ) async {
    value = value.copyWith(submitting: true, clearFailure: true);
    try {
      await repository.confirmContribution(contributionId);
      await loadCollectionDetail(collectionId);
      await load(groupId);
      return true;
    } catch (error) {
      value = value.copyWith(
        submitting: false,
        failure: FundFailure.fromError(error),
      );
      return false;
    }
  }

  Future<bool> rejectContribution(
    String groupId,
    String collectionId,
    String contributionId, {
    String? reason,
  }) async {
    value = value.copyWith(submitting: true, clearFailure: true);
    try {
      await repository.rejectContribution(contributionId, reason: reason);
      await loadCollectionDetail(collectionId);
      await load(groupId);
      return true;
    } catch (error) {
      value = value.copyWith(
        submitting: false,
        failure: FundFailure.fromError(error),
      );
      return false;
    }
  }

  Future<bool> cancelContribution(
    String groupId,
    String collectionId,
    String contributionId,
  ) async {
    value = value.copyWith(submitting: true, clearFailure: true);
    try {
      await repository.cancelContribution(contributionId);
      await loadCollectionDetail(collectionId);
      await load(groupId);
      return true;
    } catch (error) {
      value = value.copyWith(
        submitting: false,
        failure: FundFailure.fromError(error),
      );
      return false;
    }
  }

  Future<bool> createFundExpense(
    String groupId,
    String fundId, {
    required String title,
    required String amount,
    DateTime? occurredAt,
    String? activityId,
    String? receiptStorageKey,
    String? note,
  }) async {
    value = value.copyWith(submitting: true, clearFailure: true);
    try {
      await repository.createFundExpense(
        fundId,
        title: title,
        amount: amount,
        occurredAt: occurredAt,
        activityId: activityId,
        receiptStorageKey: receiptStorageKey,
        note: note,
      );
      await load(groupId);
      return true;
    } catch (error) {
      value = value.copyWith(
        submitting: false,
        failure: FundFailure.fromError(error),
      );
      return false;
    }
  }

  Future<bool> createReimbursement(
    String groupId,
    String fundId, {
    required String amount,
    required String reason,
    String? receiptStorageKey,
  }) async {
    value = value.copyWith(submitting: true, clearFailure: true);
    try {
      await repository.createReimbursement(
        fundId,
        amount: amount,
        reason: reason,
        receiptStorageKey: receiptStorageKey,
      );
      await load(groupId);
      return true;
    } catch (error) {
      value = value.copyWith(
        submitting: false,
        failure: FundFailure.fromError(error),
      );
      return false;
    }
  }

  Future<bool> approveReimbursement(
    String groupId,
    String reimbursementId,
  ) async {
    value = value.copyWith(submitting: true, clearFailure: true);
    try {
      await repository.approveReimbursement(reimbursementId);
      await load(groupId);
      return true;
    } catch (error) {
      value = value.copyWith(
        submitting: false,
        failure: FundFailure.fromError(error),
      );
      return false;
    }
  }

  Future<bool> rejectReimbursement(
    String groupId,
    String reimbursementId, {
    String? reason,
  }) async {
    value = value.copyWith(submitting: true, clearFailure: true);
    try {
      await repository.rejectReimbursement(reimbursementId, reason: reason);
      await load(groupId);
      return true;
    } catch (error) {
      value = value.copyWith(
        submitting: false,
        failure: FundFailure.fromError(error),
      );
      return false;
    }
  }

  Future<bool> cancelReimbursement(
    String groupId,
    String reimbursementId,
  ) async {
    value = value.copyWith(submitting: true, clearFailure: true);
    try {
      await repository.cancelReimbursement(reimbursementId);
      await load(groupId);
      return true;
    } catch (error) {
      value = value.copyWith(
        submitting: false,
        failure: FundFailure.fromError(error),
      );
      return false;
    }
  }

  Future<bool> reverseTransaction(
    String groupId,
    String transactionId, {
    required String reason,
  }) async {
    value = value.copyWith(submitting: true, clearFailure: true);
    try {
      await repository.reverseTransaction(transactionId, reason: reason);
      await load(groupId);
      return true;
    } catch (error) {
      value = value.copyWith(
        submitting: false,
        failure: FundFailure.fromError(error),
      );
      return false;
    }
  }
}
