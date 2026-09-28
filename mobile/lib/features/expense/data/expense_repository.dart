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
}
