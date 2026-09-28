import '../../../../core/network/api_exception.dart';

class ExpenseFailure implements Exception {
  final String message;
  const ExpenseFailure(this.message);

  factory ExpenseFailure.fromApi(ApiException error) => ExpenseFailure(
    switch (error.code) {
      'GROUP_ARCHIVED' => 'Nhóm đã lưu trữ, không thể thay đổi khoản chi.',
      'EXPENSE_UPDATE_NOT_ALLOWED' => 'Bạn không thể chỉnh sửa khoản chi này.',
      'EXPENSE_PARTICIPANT_INVALID' =>
        'Người thanh toán hoặc tham gia không còn thuộc nhóm.',
      'EXPENSE_SPLIT_TOTAL_MISMATCH' =>
        'Tổng phần chia phải bằng tổng khoản chi.',
      'INVALID_EXPENSE_AMOUNT' => 'Số tiền không hợp lệ.',
      'NO_OUTSTANDING_DEBT' =>
        'Không còn khoản nợ cần thanh toán cho chiều giao dịch này.',
      'SETTLEMENT_AMOUNT_EXCEEDS_DEBT' =>
        'Số tiền thanh toán vượt quá số nợ còn lại.',
      'SETTLEMENT_ALREADY_RESOLVED' =>
        'Giao dịch thanh toán này đã được xử lý trước đó.',
      'SETTLEMENT_CONFIRMATION_NOT_ALLOWED' =>
        'Bạn không có quyền thực hiện thao tác trên giao dịch thanh toán này.',
      'SETTLEMENT_NOT_FOUND' => 'Không tìm thấy giao dịch thanh toán.',
      'ACCESS_DENIED' ||
      'GROUP_NOT_FOUND' => 'Bạn không có quyền xem dữ liệu nhóm này.',
      _ => 'Chưa thể hoàn tất thao tác. Vui lòng thử lại.',
    },
  );
}
