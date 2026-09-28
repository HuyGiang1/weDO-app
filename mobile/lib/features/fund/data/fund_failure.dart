import '../../../core/network/api_exception.dart';

class FundFailure implements Exception {
  final String code;
  final String message;
  final int? statusCode;

  const FundFailure({
    required this.code,
    required this.message,
    this.statusCode,
  });

  bool get isNotFound => code == 'FUND_NOT_FOUND' || statusCode == 404;

  factory FundFailure.fromError(Object error) {
    if (error is FundFailure) return error;
    if (error is ApiException) {
      final code = error.code ?? 'UNKNOWN_ERROR';
      final fallback = error.message ?? '';
      return FundFailure(
        code: code,
        message: _localizedMessage(code, fallback),
        statusCode: error.statusCode,
      );
    }
    return FundFailure(
      code: 'UNKNOWN_ERROR',
      message: error.toString(),
    );
  }

  static String _localizedMessage(String code, String fallback) {
    switch (code) {
      case 'FUND_NOT_FOUND':
        return 'Nhóm hiện chưa có quỹ hoạt động.';
      case 'FUND_ALREADY_EXISTS':
        return 'Nhóm đã có quỹ đang hoạt động.';
      case 'FUND_CLOSED':
        return 'Quỹ nhóm đã đóng, không thể thực hiện thao tác này.';
      case 'FUND_MANAGER_NOT_ELIGIBLE':
        return 'Chỉ Quản trị viên (Admin) đang hoạt động mới có thể được phân quyền Quản lý quỹ.';
      case 'FUND_ACCESS_DENIED':
      case 'INSUFFICIENT_GROUP_PERMISSION':
        return 'Bạn không có quyền thực hiện thao tác quỹ này.';
      case 'FUND_COLLECTION_NOT_FOUND':
        return 'Không tìm thấy đợt thu quỹ.';
      case 'FUND_COLLECTION_NOT_OPEN':
        return 'Đợt thu quỹ đã đóng hoặc đã hủy.';
      case 'FUND_CONTRIBUTION_NOT_FOUND':
        return 'Không tìm thấy khoản đóng quỹ.';
      case 'FUND_CONTRIBUTION_EXCEEDS_OBLIGATION':
        return 'Số tiền đóng vượt quá nghĩa vụ còn lại của thành viên.';
      case 'FUND_CONTRIBUTION_ALREADY_RESOLVED':
        return 'Khoản đóng quỹ này đã được xử lý.';
      case 'FUND_INSUFFICIENT_BALANCE':
        return 'Số dư khả dụng của quỹ không đủ để thực hiện giao dịch này.';
      case 'FUND_EXPENSE_NOT_FOUND':
        return 'Không tìm thấy khoản chi quỹ.';
      case 'FUND_REIMBURSEMENT_NOT_FOUND':
        return 'Không tìm thấy yêu cầu hoàn ứng.';
      case 'FUND_REIMBURSEMENT_ALREADY_RESOLVED':
        return 'Yêu cầu hoàn ứng này đã được xử lý.';
      case 'FUND_TRANSACTION_NOT_FOUND':
        return 'Không tìm thấy giao dịch sổ quỹ.';
      case 'FUND_TRANSACTION_ALREADY_REVERSED':
        return 'Giao dịch này đã được đảo bút toán trước đó.';
      case 'FUND_REVERSAL_NOT_ALLOWED':
        return 'Không thể đảo bút toán đối với giao dịch đảo.';
      case 'FUND_CLOSE_PRECONDITION_FAILED':
        return 'Chỉ có thể đóng quỹ khi số dư bằng 0 và không còn đợt thu mở hoặc khoản chờ xử lý.';
      case 'GROUP_ARCHIVED':
        return 'Nhóm đã lưu trữ, chỉ có thể xem lịch sử quỹ.';
      default:
        return fallback.isNotEmpty ? fallback : 'Đã xảy ra lỗi khi xử lý quỹ nhóm.';
    }
  }
}
