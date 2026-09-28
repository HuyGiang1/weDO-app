import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import 'fund_models.dart';

class FundApi {
  final Dio dio;

  FundApi(this.dio);

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

  Future<FundDetail> createFund(String groupId, {String? name}) => _object(
    () => dio.post(
      '/api/v1/groups/${Uri.encodeComponent(groupId)}/fund',
      data: {if (name != null && name.trim().isNotEmpty) 'name': name.trim()},
    ),
    FundDetail.fromJson,
  );

  Future<FundDetail> getGroupFund(String groupId) => _object(
    () => dio.get('/api/v1/groups/${Uri.encodeComponent(groupId)}/fund'),
    FundDetail.fromJson,
  );

  Future<FundOverview> getFundOverview(String fundId) => _object(
    () => dio.get('/api/v1/funds/${Uri.encodeComponent(fundId)}/overview'),
    FundOverview.fromJson,
  );

  Future<FundDetail> closeFund(String fundId) => _object(
    () => dio.post('/api/v1/funds/${Uri.encodeComponent(fundId)}/close'),
    FundDetail.fromJson,
  );

  Future<List<FundManagerItem>> listManagers(String fundId) => _list(
    () => dio.get('/api/v1/funds/${Uri.encodeComponent(fundId)}/managers'),
    FundManagerItem.fromJson,
  );

  Future<FundManagerItem> assignManager(String fundId, String userId) =>
      _object(
        () => dio.post(
          '/api/v1/funds/${Uri.encodeComponent(fundId)}/managers',
          data: {'userId': userId},
        ),
        FundManagerItem.fromJson,
      );

  Future<List<FundManagerItem>> revokeManager(String fundId, String userId) =>
      _list(
        () => dio.delete(
          '/api/v1/funds/${Uri.encodeComponent(fundId)}/managers/${Uri.encodeComponent(userId)}',
        ),
        FundManagerItem.fromJson,
      );

  Future<FundCollectionDetail> createCollection(
    String fundId, {
    required String title,
    String? description,
    DateTime? deadlineAt,
    String allocationMode = 'EQUAL_PER_MEMBER',
    String? amountPerMember,
    List<String>? targetUserIds,
    List<Map<String, dynamic>>? obligations,
  }) => _object(
    () => dio.post(
      '/api/v1/funds/${Uri.encodeComponent(fundId)}/collections',
      data: {
        'title': title.trim(),
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        if (deadlineAt != null) 'deadlineAt': deadlineAt.toUtc().toIso8601String(),
        'allocationMode': allocationMode,
        'amountPerMember': ?amountPerMember,
        if (targetUserIds != null && targetUserIds.isNotEmpty)
          'targetUserIds': targetUserIds,
        if (obligations != null && obligations.isNotEmpty)
          'obligations': obligations,
      },
    ),
    FundCollectionDetail.fromJson,
  );

  Future<List<FundCollectionSummary>> listCollections(
    String fundId, {
    String? status,
  }) => _list(
    () => dio.get(
      '/api/v1/funds/${Uri.encodeComponent(fundId)}/collections',
      queryParameters: {'status': ?status},
    ),
    FundCollectionSummary.fromJson,
  );

  Future<FundCollectionDetail> getCollectionDetail(String collectionId) =>
      _object(
        () => dio.get('/api/v1/collections/${Uri.encodeComponent(collectionId)}'),
        FundCollectionDetail.fromJson,
      );

  Future<FundCollectionDetail> closeCollection(String collectionId) => _object(
    () => dio.post(
      '/api/v1/collections/${Uri.encodeComponent(collectionId)}/close',
    ),
    FundCollectionDetail.fromJson,
  );

  Future<FundCollectionDetail> cancelCollection(String collectionId) => _object(
    () => dio.post(
      '/api/v1/collections/${Uri.encodeComponent(collectionId)}/cancel',
    ),
    FundCollectionDetail.fromJson,
  );

  Future<FundContributionItem> submitContribution(
    String collectionId, {
    required String amount,
    String? userId,
    String? proofStorageKey,
    String? note,
  }) => _object(
    () => dio.post(
      '/api/v1/collections/${Uri.encodeComponent(collectionId)}/contributions',
      data: {
        'userId': ?userId,
        'amount': amount,
        if (proofStorageKey != null && proofStorageKey.trim().isNotEmpty)
          'proofStorageKey': proofStorageKey.trim(),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    ),
    FundContributionItem.fromJson,
  );

  Future<FundContributionItem> confirmContribution(String contributionId) =>
      _object(
        () => dio.post(
          '/api/v1/contributions/${Uri.encodeComponent(contributionId)}/confirm',
        ),
        FundContributionItem.fromJson,
      );

  Future<FundContributionItem> rejectContribution(
    String contributionId, {
    String? reason,
  }) => _object(
    () => dio.post(
      '/api/v1/contributions/${Uri.encodeComponent(contributionId)}/reject',
      data: {if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim()},
    ),
    FundContributionItem.fromJson,
  );

  Future<FundContributionItem> cancelContribution(String contributionId) =>
      _object(
        () => dio.post(
          '/api/v1/contributions/${Uri.encodeComponent(contributionId)}/cancel',
        ),
        FundContributionItem.fromJson,
      );

  Future<FundExpenseItem> createFundExpense(
    String fundId, {
    required String title,
    required String amount,
    DateTime? occurredAt,
    String? activityId,
    String? receiptStorageKey,
    String? note,
  }) => _object(
    () => dio.post(
      '/api/v1/funds/${Uri.encodeComponent(fundId)}/expenses',
      data: {
        'title': title.trim(),
        'amount': amount,
        if (occurredAt != null) 'occurredAt': occurredAt.toUtc().toIso8601String(),
        if (activityId != null && activityId.trim().isNotEmpty)
          'activityId': activityId.trim(),
        if (receiptStorageKey != null && receiptStorageKey.trim().isNotEmpty)
          'receiptStorageKey': receiptStorageKey.trim(),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    ),
    FundExpenseItem.fromJson,
  );

  Future<List<FundExpenseItem>> listFundExpenses(String fundId) => _list(
    () => dio.get('/api/v1/funds/${Uri.encodeComponent(fundId)}/expenses'),
    FundExpenseItem.fromJson,
  );

  Future<FundReimbursementItem> createReimbursement(
    String fundId, {
    required String amount,
    required String reason,
    String? receiptStorageKey,
  }) => _object(
    () => dio.post(
      '/api/v1/funds/${Uri.encodeComponent(fundId)}/reimbursements',
      data: {
        'amount': amount,
        'reason': reason.trim(),
        if (receiptStorageKey != null && receiptStorageKey.trim().isNotEmpty)
          'receiptStorageKey': receiptStorageKey.trim(),
      },
    ),
    FundReimbursementItem.fromJson,
  );

  Future<List<FundReimbursementItem>> listReimbursements(
    String fundId, {
    String? status,
  }) => _list(
    () => dio.get(
      '/api/v1/funds/${Uri.encodeComponent(fundId)}/reimbursements',
      queryParameters: {'status': ?status},
    ),
    FundReimbursementItem.fromJson,
  );

  Future<FundReimbursementItem> approveReimbursement(String reimbursementId) =>
      _object(
        () => dio.post(
          '/api/v1/reimbursements/${Uri.encodeComponent(reimbursementId)}/approve',
        ),
        FundReimbursementItem.fromJson,
      );

  Future<FundReimbursementItem> rejectReimbursement(
    String reimbursementId, {
    String? reason,
  }) => _object(
    () => dio.post(
      '/api/v1/reimbursements/${Uri.encodeComponent(reimbursementId)}/reject',
      data: {if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim()},
    ),
    FundReimbursementItem.fromJson,
  );

  Future<FundReimbursementItem> cancelReimbursement(String reimbursementId) =>
      _object(
        () => dio.post(
          '/api/v1/reimbursements/${Uri.encodeComponent(reimbursementId)}/cancel',
        ),
        FundReimbursementItem.fromJson,
      );

  Future<List<FundTransactionItem>> listTransactions(
    String fundId, {
    String? type,
    String? direction,
  }) => _list(
    () => dio.get(
      '/api/v1/funds/${Uri.encodeComponent(fundId)}/transactions',
      queryParameters: {
        'type': ?type,
        'direction': ?direction,
      },
    ),
    FundTransactionItem.fromJson,
  );

  Future<FundTransactionItem> reverseTransaction(
    String transactionId, {
    required String reason,
  }) => _object(
    () => dio.post(
      '/api/v1/fund-transactions/${Uri.encodeComponent(transactionId)}/reverse',
      data: {'reason': reason.trim()},
    ),
    FundTransactionItem.fromJson,
  );
}
