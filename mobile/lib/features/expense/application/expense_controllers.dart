import 'package:flutter/foundation.dart';

import '../data/expense_failure.dart';
import '../data/expense_models.dart';
import '../data/expense_repository.dart';

class ExpenseListState {
  final bool loading;
  final String? failure;
  final List<ExpenseSummary> expenses;
  final MyExpenseBalances? balances;
  const ExpenseListState({
    this.loading = false,
    this.failure,
    this.expenses = const [],
    this.balances,
  });
}

class ExpenseListController extends ChangeNotifier {
  final ExpenseRepository repository;
  bool _disposed = false;
  int _generation = 0;
  ExpenseListState state = const ExpenseListState(loading: true);
  ExpenseListController(this.repository);

  Future<void> load(String groupId) async {
    if (_disposed) return;
    final generation = ++_generation;
    state = ExpenseListState(
      loading: true,
      expenses: state.expenses,
      balances: state.balances,
    );
    notifyListeners();
    try {
      final values = await Future.wait<Object>([
        repository.list(groupId),
        repository.myBalances(groupId),
      ]);
      if (_disposed || generation != _generation) return;
      state = ExpenseListState(
        expenses: values[0] as List<ExpenseSummary>,
        balances: values[1] as MyExpenseBalances,
      );
    } on ExpenseFailure catch (error) {
      if (_disposed || generation != _generation) return;
      state = ExpenseListState(failure: error.message);
    } catch (_) {
      if (_disposed || generation != _generation) return;
      state = const ExpenseListState(
        failure: 'Chưa thể tải khoản chi. Vui lòng thử lại.',
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class ExpenseFormController extends ChangeNotifier {
  final ExpenseRepository repository;
  bool _disposed = false;
  bool saving = false;
  String? failure;
  ExpenseFormController(this.repository);

  Future<ExpenseDetail?> save(
    String groupId,
    ExpenseDraft draft, {
    String? expenseId,
  }) async {
    saving = true;
    failure = null;
    notifyListeners();
    try {
      final result = expenseId == null
          ? await repository.create(groupId, draft)
          : await repository.update(expenseId, draft);
      return result;
    } on ExpenseFailure catch (error) {
      failure = error.message;
      return null;
    } catch (_) {
      failure = 'Chưa thể lưu khoản chi. Vui lòng thử lại.';
      return null;
    } finally {
      saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
