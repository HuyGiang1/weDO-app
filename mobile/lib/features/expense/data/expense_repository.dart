import '../../../../core/network/api_exception.dart';
import 'expense_api.dart';
import 'expense_failure.dart';
import 'expense_models.dart';

class ExpenseRepository {
  final ExpenseApi api;
  const ExpenseRepository(this.api);

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiException catch (error) {
      throw ExpenseFailure.fromApi(error);
    }
  }

  Future<List<ExpenseSummary>> list(String groupId) =>
      _guard(() => api.list(groupId));
  Future<ExpenseDetail> detail(String id) => _guard(() => api.detail(id));
  Future<ExpenseDetail> create(String groupId, ExpenseDraft draft) =>
      _guard(() => api.create(groupId, draft));
  Future<ExpenseDetail> update(String id, ExpenseDraft draft) =>
      _guard(() => api.update(id, draft));
  Future<ExpenseDetail> cancel(String id) => _guard(() => api.cancel(id));
  Future<MyExpenseBalances> myBalances(String groupId) =>
      _guard(() => api.myBalances(groupId));
  Future<List<SettlementItem>> listSettlements(
    String groupId, {
    String? status,
    bool? involvingMe,
    String? otherUserId,
  }) => _guard(
    () => api.listSettlements(
      groupId,
      status: status,
      involvingMe: involvingMe,
      otherUserId: otherUserId,
    ),
  );
  Future<SettlementItem> settlementDetail(String settlementId) =>
      _guard(() => api.settlementDetail(settlementId));
  Future<SettlementItem> createSettlement(
    String groupId,
    CreateSettlementDraft draft,
  ) => _guard(() => api.createSettlement(groupId, draft));
  Future<SettlementItem> confirmSettlement(String settlementId) =>
      _guard(() => api.confirmSettlement(settlementId));
  Future<SettlementItem> rejectSettlement(String settlementId) =>
      _guard(() => api.rejectSettlement(settlementId));
  Future<SettlementItem> cancelSettlement(String settlementId) =>
      _guard(() => api.cancelSettlement(settlementId));
}
