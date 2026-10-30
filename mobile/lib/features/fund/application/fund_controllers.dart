import 'package:flutter/foundation.dart';

import '../data/fund_failure.dart';
import '../data/fund_models.dart';
import '../data/fund_repository.dart';

class GroupFundState {
  final bool loading;
  final bool submitting;
  final bool stale;
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
    this.stale = false,
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
    bool? stale,
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
    stale: stale ?? this.stale,
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
  bool _disposed = false;
  int _resyncGeneration = 0;
  int _collectionGeneration = 0, _accessGeneration = 0;
  bool _accessDenied = false;

  void revokeAccess() {
    if (_disposed) return;
    _resyncGeneration++;
    _collectionGeneration++;
    _accessGeneration++;
    _accessDenied = true;
    value = const GroupFundState(failure: FundFailure(
      code: 'FUND_ACCESS_DENIED', message: 'Bạn không có quyền xem quỹ này.', statusCode: 403));
  }

  void _readFailed(Object error, GroupFundState previous) {
    final failure = FundFailure.fromError(error);
    value = failure.isTransient && previous.fund != null
        ? previous.copyWith(loading: false, stale: true, failure: failure)
        : GroupFundState(failure: failure);
  }

  GroupFundController(this.repository) : super(const GroupFundState());

  Future<void> resync(String groupId, {Set<String> eventTypes = const {}}) async {
    if (_disposed) return;
    final generation = ++_resyncGeneration;
    final previous = value;
    try {
      final fund = await repository.getGroupFund(groupId);
      final active = previous.activeCollectionDetail;
      final full = eventTypes.isEmpty || eventTypes.contains('*') ||
          eventTypes.any((type) => type == 'FUND_MANAGER_CHANGED' || type == 'FUND_CREATED' ||
              type == 'FUND_CLOSED' || type == 'FUND_TRANSACTION_REVERSED');
      final collections = full || eventTypes.any((type) => type.startsWith('FUND_COLLECTION_') || type.startsWith('FUND_CONTRIBUTION_'));
      final expenses = full || eventTypes.contains('FUND_EXPENSE_CREATED');
      final reimbursements = full || eventTypes.any((type) => type.startsWith('FUND_REIMBURSEMENT_'));
      final transactions = full || expenses || reimbursements || eventTypes.contains('FUND_CONTRIBUTION_APPROVED');
      final results = await Future.wait<dynamic>([
        collections ? repository.listCollections(fund.fundId) : Future.value(previous.collections),
        expenses ? repository.listFundExpenses(fund.fundId) : Future.value(previous.expenses),
        reimbursements ? repository.listReimbursements(fund.fundId) : Future.value(previous.reimbursements),
        transactions ? repository.listTransactions(fund.fundId) : Future.value(previous.transactions),
        if (active != null) collections ? repository.getCollectionDetail(active.collectionId) : Future.value(active),
      ]);
      if (_disposed || generation != _resyncGeneration || !identical(previous, value)) return;
      _accessDenied = false;
      value = GroupFundState(
        fund: fund, submitting: previous.submitting,
        collections: results[0] as List<FundCollectionSummary>,
        expenses: results[1] as List<FundExpenseItem>,
        reimbursements: results[2] as List<FundReimbursementItem>,
        transactions: results[3] as List<FundTransactionItem>,
        activeCollectionDetail: active == null ? null : results[4] as FundCollectionDetail,
      );
    } catch (error) {
      if (_disposed || generation != _resyncGeneration || !identical(previous, value)) return;
      _readFailed(error, previous);
    }
  }

  @override
  void dispose() { _disposed = true; _resyncGeneration++; _collectionGeneration++; super.dispose(); }

  Future<void> load(String groupId) async {
    if (_disposed) return;
    final generation = ++_resyncGeneration;
    value = value.copyWith(loading: true, clearFailure: true);
    try {
      final fund = await repository.getGroupFund(groupId);
      if (_disposed || generation != _resyncGeneration) return;
      await _loadFundWorkspace(fund, generation: generation);
    } catch (error) {
      if (_disposed || generation != _resyncGeneration) return;
      final failure = FundFailure.fromError(error);
      if (failure.code == 'FUND_NOT_FOUND') {
        value = const GroupFundState(notCreatedYet: true);
      } else {
        _readFailed(error, value);
      }
    }
  }

  Future<void> _loadFundWorkspace(FundDetail fund, {int? generation}) async {
    final access = _accessGeneration;
    final results = await Future.wait<dynamic>([
      repository.listCollections(fund.fundId),
      repository.listFundExpenses(fund.fundId),
      repository.listReimbursements(fund.fundId),
      repository.listTransactions(fund.fundId),
    ]);
    if (_disposed || access != _accessGeneration || (generation != null && generation != _resyncGeneration)) return;
    _accessDenied = false;
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
    if (_disposed || _accessDenied || value.stale) return false;
    final access = _accessGeneration;
    value = value.copyWith(submitting: true, clearFailure: true);
    try {
      final created = await repository.createFund(groupId, name: name);
      if (_disposed || access != _accessGeneration) return false;
      await _loadFundWorkspace(created);
      if (_disposed || access != _accessGeneration) return false;
      return true;
    } catch (error) {
      if (_disposed || access != _accessGeneration) return false;
      value = value.copyWith(
        submitting: false,
        failure: FundFailure.fromError(error),
      );
      return false;
    }
  }

  Future<bool> closeFund(String groupId, String fundId) async {
    if (_disposed || _accessDenied || value.stale) return false;
    final access = _accessGeneration;
    value = value.copyWith(submitting: true, clearFailure: true);
    try {
      await repository.closeFund(fundId);
      if (_disposed || access != _accessGeneration) return false;
      await load(groupId);
      if (_disposed || access != _accessGeneration) return false;
      return true;
    } catch (error) {
      if (_disposed || access != _accessGeneration) return false;
      value = value.copyWith(
        submitting: false,
        failure: FundFailure.fromError(error),
      );
      return false;
    }
  }

  Future<bool> assignManager(String groupId, String fundId, String userId) async {
    if (_disposed || _accessDenied || value.stale) return false;
    final access = _accessGeneration;
    value = value.copyWith(submitting: true, clearFailure: true);
    try {
      await repository.assignManager(fundId, userId);
      if (_disposed || access != _accessGeneration) return false;
      await load(groupId);
      if (_disposed || access != _accessGeneration) return false;
      return true;
    } catch (error) {
      if (_disposed || access != _accessGeneration) return false;
      value = value.copyWith(
        submitting: false,
        failure: FundFailure.fromError(error),
      );
      return false;
    }
  }

  Future<bool> revokeManager(String groupId, String fundId, String userId) async {
    if (_disposed || _accessDenied || value.stale) return false;
    final access = _accessGeneration;
    value = value.copyWith(submitting: true, clearFailure: true);
    try {
      await repository.revokeManager(fundId, userId);
      if (_disposed || access != _accessGeneration) return false;
      await load(groupId);
      if (_disposed || access != _accessGeneration) return false;
      return true;
    } catch (error) {
      if (_disposed || access != _accessGeneration) return false;
      value = value.copyWith(
        submitting: false,
        failure: FundFailure.fromError(error),
      );
      return false;
    }
  }

  Future<FundCollectionDetail?> loadCollectionDetail(String collectionId) async {
    if (_disposed) return null;
    final generation = ++_collectionGeneration;
    final workspaceGeneration = _resyncGeneration;
    try {
      final detail = await repository.getCollectionDetail(collectionId);
      if (_disposed || generation != _collectionGeneration || workspaceGeneration != _resyncGeneration) return null;
      value = value.copyWith(activeCollectionDetail: detail, clearFailure: true);
      return detail;
    } catch (error) {
      if (_disposed || generation != _collectionGeneration || workspaceGeneration != _resyncGeneration) return null;
      final failure = FundFailure.fromError(error);
      if ([401,403,404].contains(failure.statusCode)) {
        revokeAccess();
      } else {
        value = value.copyWith(failure: failure);
      }
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
    if (_disposed || _accessDenied || value.stale) return false;
    final access = _accessGeneration;
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
      if (_disposed || access != _accessGeneration) return false;
      value = value.copyWith(activeCollectionDetail: detail);
      await load(groupId);
      if (_disposed || access != _accessGeneration) return false;
      return true;
    } catch (error) {
      if (_disposed || access != _accessGeneration) return false;
      value = value.copyWith(
        submitting: false,
        failure: FundFailure.fromError(error),
      );
      return false;
    }
  }

  Future<bool> closeCollection(String groupId, String collectionId) async {
    if (_disposed || _accessDenied || value.stale) return false;
    final access = _accessGeneration;
    value = value.copyWith(submitting: true, clearFailure: true);
    try {
      final detail = await repository.closeCollection(collectionId);
      if (_disposed || access != _accessGeneration) return false;
      value = value.copyWith(activeCollectionDetail: detail);
      await load(groupId);
      if (_disposed || access != _accessGeneration) return false;
      return true;
    } catch (error) {
      if (_disposed || access != _accessGeneration) return false;
      value = value.copyWith(
        submitting: false,
        failure: FundFailure.fromError(error),
      );
      return false;
    }
  }

  Future<bool> cancelCollection(String groupId, String collectionId) async {
    if (_disposed || _accessDenied || value.stale) return false;
    final access = _accessGeneration;
    value = value.copyWith(submitting: true, clearFailure: true);
    try {
      final detail = await repository.cancelCollection(collectionId);
      if (_disposed || access != _accessGeneration) return false;
      value = value.copyWith(activeCollectionDetail: detail);
      await load(groupId);
      if (_disposed || access != _accessGeneration) return false;
      return true;
    } catch (error) {
      if (_disposed || access != _accessGeneration) return false;
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
    if (_disposed || _accessDenied || value.stale) return false;
    final access = _accessGeneration;
    value = value.copyWith(submitting: true, clearFailure: true);
    try {
      await repository.submitContribution(
        collectionId,
        amount: amount,
        userId: userId,
        proofStorageKey: proofStorageKey,
        note: note,
      );
      if (_disposed || access != _accessGeneration) return false;
      await loadCollectionDetail(collectionId);
      if (_disposed || access != _accessGeneration) return false;
      await load(groupId);
      if (_disposed || access != _accessGeneration) return false;
      return true;
    } catch (error) {
      if (_disposed || access != _accessGeneration) return false;
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
    if (_disposed || _accessDenied || value.stale) return false;
    final access = _accessGeneration;
    value = value.copyWith(submitting: true, clearFailure: true);
    try {
      await repository.confirmContribution(contributionId);
      if (_disposed || access != _accessGeneration) return false;
      await loadCollectionDetail(collectionId);
      if (_disposed || access != _accessGeneration) return false;
      await load(groupId);
      if (_disposed || access != _accessGeneration) return false;
      return true;
    } catch (error) {
      if (_disposed || access != _accessGeneration) return false;
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
    if (_disposed || _accessDenied || value.stale) return false;
    final access = _accessGeneration;
    value = value.copyWith(submitting: true, clearFailure: true);
    try {
      await repository.rejectContribution(contributionId, reason: reason);
      if (_disposed || access != _accessGeneration) return false;
      await loadCollectionDetail(collectionId);
      if (_disposed || access != _accessGeneration) return false;
      await load(groupId);
      if (_disposed || access != _accessGeneration) return false;
      return true;
    } catch (error) {
      if (_disposed || access != _accessGeneration) return false;
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
    if (_disposed || _accessDenied || value.stale) return false;
    final access = _accessGeneration;
    value = value.copyWith(submitting: true, clearFailure: true);
    try {
      await repository.cancelContribution(contributionId);
      if (_disposed || access != _accessGeneration) return false;
      await loadCollectionDetail(collectionId);
      if (_disposed || access != _accessGeneration) return false;
      await load(groupId);
      if (_disposed || access != _accessGeneration) return false;
      return true;
    } catch (error) {
      if (_disposed || access != _accessGeneration) return false;
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
    if (_disposed || _accessDenied || value.stale) return false;
    final access = _accessGeneration;
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
      if (_disposed || access != _accessGeneration) return false;
      await load(groupId);
      if (_disposed || access != _accessGeneration) return false;
      return true;
    } catch (error) {
      if (_disposed || access != _accessGeneration) return false;
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
    if (_disposed || _accessDenied || value.stale) return false;
    final access = _accessGeneration;
    value = value.copyWith(submitting: true, clearFailure: true);
    try {
      await repository.createReimbursement(
        fundId,
        amount: amount,
        reason: reason,
        receiptStorageKey: receiptStorageKey,
      );
      if (_disposed || access != _accessGeneration) return false;
      await load(groupId);
      if (_disposed || access != _accessGeneration) return false;
      return true;
    } catch (error) {
      if (_disposed || access != _accessGeneration) return false;
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
    if (_disposed || _accessDenied || value.stale) return false;
    final access = _accessGeneration;
    value = value.copyWith(submitting: true, clearFailure: true);
    try {
      await repository.approveReimbursement(reimbursementId);
      if (_disposed || access != _accessGeneration) return false;
      await load(groupId);
      if (_disposed || access != _accessGeneration) return false;
      return true;
    } catch (error) {
      if (_disposed || access != _accessGeneration) return false;
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
    if (_disposed || _accessDenied || value.stale) return false;
    final access = _accessGeneration;
    value = value.copyWith(submitting: true, clearFailure: true);
    try {
      await repository.rejectReimbursement(reimbursementId, reason: reason);
      if (_disposed || access != _accessGeneration) return false;
      await load(groupId);
      if (_disposed || access != _accessGeneration) return false;
      return true;
    } catch (error) {
      if (_disposed || access != _accessGeneration) return false;
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
    if (_disposed || _accessDenied || value.stale) return false;
    final access = _accessGeneration;
    value = value.copyWith(submitting: true, clearFailure: true);
    try {
      await repository.cancelReimbursement(reimbursementId);
      if (_disposed || access != _accessGeneration) return false;
      await load(groupId);
      if (_disposed || access != _accessGeneration) return false;
      return true;
    } catch (error) {
      if (_disposed || access != _accessGeneration) return false;
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
    if (_disposed || _accessDenied || value.stale) return false;
    final access = _accessGeneration;
    value = value.copyWith(submitting: true, clearFailure: true);
    try {
      await repository.reverseTransaction(transactionId, reason: reason);
      if (_disposed || access != _accessGeneration) return false;
      await load(groupId);
      if (_disposed || access != _accessGeneration) return false;
      return true;
    } catch (error) {
      if (_disposed || access != _accessGeneration) return false;
      value = value.copyWith(
        submitting: false,
        failure: FundFailure.fromError(error),
      );
      return false;
    }
  }
}
