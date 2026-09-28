import 'fund_api.dart';
import 'fund_failure.dart';
import 'fund_models.dart';

class FundRepository {
  final FundApi api;

  const FundRepository(this.api);

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw FundFailure.fromError(error);
    }
  }

  Future<FundDetail> createFund(String groupId, {String? name}) =>
      _guard(() => api.createFund(groupId, name: name));

  Future<FundDetail> getGroupFund(String groupId) =>
      _guard(() => api.getGroupFund(groupId));

  Future<FundOverview> getFundOverview(String fundId) =>
      _guard(() => api.getFundOverview(fundId));

  Future<FundDetail> closeFund(String fundId) =>
      _guard(() => api.closeFund(fundId));

  Future<List<FundManagerItem>> listManagers(String fundId) =>
      _guard(() => api.listManagers(fundId));

  Future<FundManagerItem> assignManager(String fundId, String userId) =>
      _guard(() => api.assignManager(fundId, userId));

  Future<List<FundManagerItem>> revokeManager(String fundId, String userId) =>
      _guard(() => api.revokeManager(fundId, userId));

  Future<FundCollectionDetail> createCollection(
    String fundId, {
    required String title,
    String? description,
    DateTime? deadlineAt,
    String allocationMode = 'EQUAL_PER_MEMBER',
    String? amountPerMember,
    List<String>? targetUserIds,
    List<Map<String, dynamic>>? obligations,
  }) => _guard(
    () => api.createCollection(
      fundId,
      title: title,
      description: description,
      deadlineAt: deadlineAt,
      allocationMode: allocationMode,
      amountPerMember: amountPerMember,
      targetUserIds: targetUserIds,
      obligations: obligations,
    ),
  );

  Future<List<FundCollectionSummary>> listCollections(
    String fundId, {
    String? status,
  }) => _guard(() => api.listCollections(fundId, status: status));

  Future<FundCollectionDetail> getCollectionDetail(String collectionId) =>
      _guard(() => api.getCollectionDetail(collectionId));

  Future<FundCollectionDetail> closeCollection(String collectionId) =>
      _guard(() => api.closeCollection(collectionId));

  Future<FundCollectionDetail> cancelCollection(String collectionId) =>
      _guard(() => api.cancelCollection(collectionId));

  Future<FundContributionItem> submitContribution(
    String collectionId, {
    required String amount,
    String? userId,
    String? proofStorageKey,
    String? note,
  }) => _guard(
    () => api.submitContribution(
      collectionId,
      amount: amount,
      userId: userId,
      proofStorageKey: proofStorageKey,
      note: note,
    ),
  );

  Future<FundContributionItem> confirmContribution(String contributionId) =>
      _guard(() => api.confirmContribution(contributionId));

  Future<FundContributionItem> rejectContribution(
    String contributionId, {
    String? reason,
  }) => _guard(() => api.rejectContribution(contributionId, reason: reason));

  Future<FundContributionItem> cancelContribution(String contributionId) =>
      _guard(() => api.cancelContribution(contributionId));

  Future<FundExpenseItem> createFundExpense(
    String fundId, {
    required String title,
    required String amount,
    DateTime? occurredAt,
    String? activityId,
    String? receiptStorageKey,
    String? note,
  }) => _guard(
    () => api.createFundExpense(
      fundId,
      title: title,
      amount: amount,
      occurredAt: occurredAt,
      activityId: activityId,
      receiptStorageKey: receiptStorageKey,
      note: note,
    ),
  );

  Future<List<FundExpenseItem>> listFundExpenses(String fundId) =>
      _guard(() => api.listFundExpenses(fundId));

  Future<FundReimbursementItem> createReimbursement(
    String fundId, {
    required String amount,
    required String reason,
    String? receiptStorageKey,
  }) => _guard(
    () => api.createReimbursement(
      fundId,
      amount: amount,
      reason: reason,
      receiptStorageKey: receiptStorageKey,
    ),
  );

  Future<List<FundReimbursementItem>> listReimbursements(
    String fundId, {
    String? status,
  }) => _guard(() => api.listReimbursements(fundId, status: status));

  Future<FundReimbursementItem> approveReimbursement(String reimbursementId) =>
      _guard(() => api.approveReimbursement(reimbursementId));

  Future<FundReimbursementItem> rejectReimbursement(
    String reimbursementId, {
    String? reason,
  }) => _guard(() => api.rejectReimbursement(reimbursementId, reason: reason));

  Future<FundReimbursementItem> cancelReimbursement(String reimbursementId) =>
      _guard(() => api.cancelReimbursement(reimbursementId));

  Future<List<FundTransactionItem>> listTransactions(
    String fundId, {
    String? type,
    String? direction,
  }) => _guard(
    () => api.listTransactions(fundId, type: type, direction: direction),
  );

  Future<FundTransactionItem> reverseTransaction(
    String transactionId, {
    required String reason,
  }) => _guard(() => api.reverseTransaction(transactionId, reason: reason));
}
