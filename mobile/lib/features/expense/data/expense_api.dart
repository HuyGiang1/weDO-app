import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import 'expense_models.dart';

class ExpenseApi {
  final Dio dio;
  ExpenseApi(this.dio);

  Future<T> _object<T>(
    Future<Response<dynamic>> Function() call,
    T Function(Map<String, dynamic>) parse,
  ) async {
    try {
      final data = (await call()).data;
      if (data is! Map) throw const FormatException('Expected object response');
      return parse(Map<String, dynamic>.from(data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<T>> _list<T>(
    Future<Response<dynamic>> Function() call,
    T Function(Map<String, dynamic>) parse,
  ) async {
    try {
      final data = (await call()).data;
      if (data is! List) throw const FormatException('Expected list response');
      return data
          .map((v) => parse(Map<String, dynamic>.from(v as Map)))
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<ExpenseSummary>> list(String groupId) => _list(
    () => dio.get('/api/v1/groups/${Uri.encodeComponent(groupId)}/expenses'),
    ExpenseSummary.fromJson,
  );

  Future<ExpenseDetail> detail(String expenseId) => _object(
    () => dio.get('/api/v1/expenses/${Uri.encodeComponent(expenseId)}'),
    ExpenseDetail.fromJson,
  );

  Future<ExpenseDetail> create(String groupId, ExpenseDraft draft) => _object(
    () => dio.post(
      '/api/v1/groups/${Uri.encodeComponent(groupId)}/expenses',
      data: draft.toJson(),
    ),
    ExpenseDetail.fromJson,
  );

  Future<ExpenseDetail> update(String expenseId, ExpenseDraft draft) => _object(
    () => dio.patch(
      '/api/v1/expenses/${Uri.encodeComponent(expenseId)}',
      data: draft.toJson(),
    ),
    ExpenseDetail.fromJson,
  );

  Future<ExpenseDetail> cancel(String expenseId) => _object(
    () => dio.post('/api/v1/expenses/${Uri.encodeComponent(expenseId)}/cancel'),
    ExpenseDetail.fromJson,
  );

  Future<MyExpenseBalances> myBalances(String groupId) => _object(
    () => dio.get('/api/v1/groups/${Uri.encodeComponent(groupId)}/balances/me'),
    MyExpenseBalances.fromJson,
  );
}
