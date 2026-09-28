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

class SettlementBalanceState {
  final bool loading;
  final bool working;
  final String? failure;
  final MyExpenseBalances? balances;
  final List<SettlementItem> settlements;

  const SettlementBalanceState({
    this.loading = false,
    this.working = false,
    this.failure,
    this.balances,
    this.settlements = const [],
  });
}

class SettlementBalanceController extends ChangeNotifier {
  final ExpenseRepository repository;
  bool _disposed = false;
  int _generation = 0;
  SettlementBalanceState state = const SettlementBalanceState(loading: true);

  SettlementBalanceController(this.repository);

  Future<void> load(String groupId) async {
    if (_disposed) return;
    final generation = ++_generation;
    state = SettlementBalanceState(
      loading: true,
      working: state.working,
      balances: state.balances,
      settlements: state.settlements,
    );
    notifyListeners();
    try {
      final values = await Future.wait<Object>([
        repository.myBalances(groupId),
        repository.listSettlements(groupId),
      ]);
      if (_disposed || generation != _generation) return;
      state = SettlementBalanceState(
        balances: values[0] as MyExpenseBalances,
        settlements: values[1] as List<SettlementItem>,
      );
    } on ExpenseFailure catch (error) {
      if (_disposed || generation != _generation) return;
      state = SettlementBalanceState(
        failure: error.message,
        balances: state.balances,
        settlements: state.settlements,
      );
    } catch (_) {
      if (_disposed || generation != _generation) return;
      state = SettlementBalanceState(
        failure: 'Chưa thể tải dữ liệu thanh toán. Vui lòng thử lại.',
        balances: state.balances,
        settlements: state.settlements,
      );
    }
    notifyListeners();
  }

  Future<SettlementItem?> createSettlement(
    String groupId,
    CreateSettlementDraft draft,
  ) => _mutate(groupId, () => repository.createSettlement(groupId, draft));

  Future<SettlementItem?> confirm(String groupId, String settlementId) =>
      _mutate(groupId, () => repository.confirmSettlement(settlementId));

  Future<SettlementItem?> reject(String groupId, String settlementId) =>
      _mutate(groupId, () => repository.rejectSettlement(settlementId));

  Future<SettlementItem?> cancel(String groupId, String settlementId) =>
      _mutate(groupId, () => repository.cancelSettlement(settlementId));

  Future<SettlementItem?> _mutate(
    String groupId,
    Future<SettlementItem> Function() action,
  ) async {
    if (_disposed) return null;
    state = SettlementBalanceState(
      loading: state.loading,
      working: true,
      balances: state.balances,
      settlements: state.settlements,
    );
    notifyListeners();
    try {
      final item = await action();
      await load(groupId);
      return item;
    } on ExpenseFailure catch (error) {
      if (!_disposed) {
        state = SettlementBalanceState(
          failure: error.message,
          balances: state.balances,
          settlements: state.settlements,
        );
        notifyListeners();
      }
      return null;
    } catch (_) {
      if (!_disposed) {
        state = SettlementBalanceState(
          failure: 'Chưa thể thực hiện thao tác thanh toán. Vui lòng thử lại.',
          balances: state.balances,
          settlements: state.settlements,
        );
        notifyListeners();
      }
      return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
