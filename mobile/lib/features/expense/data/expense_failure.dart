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
      'ACCESS_DENIED' ||
      'GROUP_NOT_FOUND' => 'Bạn không có quyền xem dữ liệu nhóm này.',
      _ => 'Chưa thể hoàn tất thao tác. Vui lòng thử lại.',
    },
  );
}
