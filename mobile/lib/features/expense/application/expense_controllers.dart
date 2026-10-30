import 'package:flutter/foundation.dart';

import '../../../core/realtime/reliable_read.dart';

import '../data/expense_failure.dart';
import '../data/expense_models.dart';
import '../data/expense_repository.dart';

ReadFailure? _readFailure(Object error) => error is ExpenseFailure
    ? (error.apiError == null
          ? ReadFailure(error.message)
          : ReadFailure.fromError(error.apiError!))
    : ReadFailure.fromError(error);

void _reportUnexpected(Object error, StackTrace stack) {
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'Expense authoritative read',
    ),
  );
}

// Future.wait reports its first failure. A later denial from the other read
// must still clear the same request's cache, even after a transient first error.
Future<T> _guardAccess<T>(
  Future<T> read,
  bool Function() isCurrent,
  VoidCallback denyAccess,
) async {
  try {
    return await read;
  } catch (error) {
    if (isCurrent() && _readFailure(error)?.accessDenied == true) denyAccess();
    rethrow;
  }
}

class ExpenseListState {
  final bool loading;
  final String? failure;
  final List<ExpenseSummary> expenses;
  final MyExpenseBalances? balances;
  final bool stale, accessDenied, refreshing;
  bool get hasLoaded => balances != null;
  bool get canMutate => hasLoaded && !stale && !accessDenied && !refreshing;
  const ExpenseListState({
    this.loading = false,
    this.failure,
    this.expenses = const [],
    this.balances,
    this.stale = false,
    this.accessDenied = false,
    this.refreshing = false,
  });
}

class ExpenseListController extends ChangeNotifier {
  final ExpenseRepository repository;
  bool _disposed = false;
  int _generation = 0;
  String? _groupId;
  bool _recoverableReadFailure = false;
  bool get needsReadRecovery =>
      !_disposed &&
      _recoverableReadFailure &&
      !state.refreshing &&
      !state.accessDenied;
  ExpenseListState state = const ExpenseListState(loading: true);
  ExpenseListController(this.repository);

  Future<void> load(String groupId, {bool silent = false}) async {
    if (_disposed) return;
    if (_groupId != groupId) {
      _groupId = groupId;
      _recoverableReadFailure = false;
      state = const ExpenseListState();
    }
    final generation = ++_generation;
    state = ExpenseListState(
      loading: !state.hasLoaded,
      refreshing: true,
      failure: state.failure,
      stale: state.stale,
      accessDenied: state.accessDenied,
      expenses: state.expenses,
      balances: state.balances,
    );
    notifyListeners();
    try {
      final values = await Future.wait<Object>([
        _guardAccess(
          repository.list(groupId),
          () => !_disposed && generation == _generation,
          denyAccess,
        ),
        _guardAccess(
          repository.myBalances(groupId),
          () => !_disposed && generation == _generation,
          denyAccess,
        ),
      ], eagerError: true);
      if (_disposed || generation != _generation) return;
      _recoverableReadFailure = false;
      state = ExpenseListState(
        expenses: values[0] as List<ExpenseSummary>,
        balances: values[1] as MyExpenseBalances,
      );
    } catch (error, stack) {
      final failure = _readFailure(error);
      if (failure == null) _reportUnexpected(error, stack);
      if (_disposed || generation != _generation) return;
      final denied = failure?.accessDenied == true || state.accessDenied;
      final retain = failure?.retainData == true && !denied;
      _recoverableReadFailure = retain;
      state = ExpenseListState(
        failure: denied && failure?.accessDenied != true
            ? state.failure
            : (error is ExpenseFailure ? error.message : failure?.message) ??
                  'Chưa thể tải khoản chi. Vui lòng thử lại.',
        expenses: retain ? state.expenses : const [],
        balances: retain ? state.balances : null,
        stale: retain && state.hasLoaded,
        accessDenied: denied,
      );
    }
    notifyListeners();
  }

  void denyAccess() {
    if (_disposed) return;
    _recoverableReadFailure = false;
    _generation++;
    state = const ExpenseListState(
      failure: 'Bạn không có quyền xem dữ liệu nhóm này.',
      accessDenied: true,
    );
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
  final bool stale, accessDenied, refreshing;
  bool get canMutate =>
      balances != null && !stale && !accessDenied && !refreshing && !working;

  const SettlementBalanceState({
    this.loading = false,
    this.working = false,
    this.failure,
    this.balances,
    this.settlements = const [],
    this.stale = false,
    this.accessDenied = false,
    this.refreshing = false,
  });
}

class SettlementBalanceController extends ChangeNotifier {
  final ExpenseRepository repository;
  bool _disposed = false;
  int _generation = 0;
  String? _groupId;
  bool _recoverableReadFailure = false;
  bool get needsReadRecovery =>
      !_disposed &&
      _recoverableReadFailure &&
      !state.refreshing &&
      !state.working &&
      !state.accessDenied;
  SettlementBalanceState state = const SettlementBalanceState(loading: true);

  SettlementBalanceController(this.repository);

  Future<void> load(String groupId, {bool silent = false}) async {
    if (_disposed) return;
    if (_groupId != groupId) {
      _groupId = groupId;
      _recoverableReadFailure = false;
      state = const SettlementBalanceState();
    }
    final generation = ++_generation;
    state = SettlementBalanceState(
      loading: state.balances == null,
      refreshing: true,
      failure: state.failure,
      stale: state.stale,
      accessDenied: state.accessDenied,
      working: state.working,
      balances: state.balances,
      settlements: state.settlements,
    );
    notifyListeners();
    try {
      final values = await Future.wait<Object>([
        _guardAccess(
          repository.myBalances(groupId),
          () => !_disposed && generation == _generation,
          denyAccess,
        ),
        _guardAccess(
          repository.listSettlements(groupId),
          () => !_disposed && generation == _generation,
          denyAccess,
        ),
      ], eagerError: true);
      if (_disposed || generation != _generation) return;
      _recoverableReadFailure = false;
      state = SettlementBalanceState(
        balances: values[0] as MyExpenseBalances,
        settlements: values[1] as List<SettlementItem>,
      );
    } catch (error, stack) {
      final failure = _readFailure(error);
      if (failure == null) _reportUnexpected(error, stack);
      if (_disposed || generation != _generation) return;
      final denied = failure?.accessDenied == true || state.accessDenied;
      final retain = failure?.retainData == true && !denied;
      _recoverableReadFailure = retain;
      state = SettlementBalanceState(
        failure: denied && failure?.accessDenied != true
            ? state.failure
            : (error is ExpenseFailure ? error.message : failure?.message) ??
                  'Chưa thể tải dữ liệu thanh toán. Vui lòng thử lại.',
        balances: retain ? state.balances : null,
        settlements: retain ? state.settlements : const [],
        stale: retain && state.balances != null,
        accessDenied: denied,
      );
    }
    notifyListeners();
  }

  void denyAccess() {
    if (_disposed) return;
    _recoverableReadFailure = false;
    _generation++;
    state = const SettlementBalanceState(
      failure: 'Bạn không có quyền xem dữ liệu nhóm này.',
      accessDenied: true,
    );
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
    if (_disposed || groupId != _groupId || !state.canMutate) return null;
    final generation = ++_generation;
    state = SettlementBalanceState(
      loading: state.loading,
      working: true,
      balances: state.balances,
      settlements: state.settlements,
    );
    notifyListeners();
    try {
      final item = await action();
      if (_disposed || generation != _generation) return null;
      await load(groupId);
      return item;
    } on ExpenseFailure catch (error) {
      if (!_disposed && generation == _generation) {
        final denied = _readFailure(error)?.accessDenied == true;
        state = SettlementBalanceState(
          failure: error.message,
          balances: denied ? null : state.balances,
          settlements: denied ? const [] : state.settlements,
          stale: !denied && state.balances != null,
          accessDenied: denied,
        );
        notifyListeners();
      }
      return null;
    } catch (error, stack) {
      _reportUnexpected(error, stack);
      if (!_disposed && generation == _generation) {
        state = SettlementBalanceState(
          failure: 'Chưa thể thực hiện thao tác thanh toán. Vui lòng thử lại.',
          balances: state.balances,
          settlements: state.settlements,
          stale: state.balances != null,
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
