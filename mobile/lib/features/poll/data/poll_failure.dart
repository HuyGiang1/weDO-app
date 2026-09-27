import '../../../core/network/api_exception.dart';

String createPollFailureMessage(Object error) {
  if (error is! ApiException) return 'Không thể tạo bình chọn.';

  if (error.transportFailure == ApiTransportFailure.network) {
    return 'Không thể kết nối đến máy chủ. Vui lòng thử lại.';
  }
  if (error.transportFailure == ApiTransportFailure.timeout) {
    return 'Kết nối đến máy chủ quá lâu. Vui lòng thử lại.';
  }

  return switch (error.code) {
    'VALIDATION_FAILED' ||
    'INVALID_POLL_SELECTION' ||
    'MAX_POLL_SELECTIONS_EXCEEDED' => 'Thông tin bình chọn chưa hợp lệ. Kiểm tra câu hỏi, lựa chọn và hạn bình chọn.',
    'POLL_DEADLINE_PASSED' => 'Hạn bình chọn phải nằm trong tương lai.',
    'INSUFFICIENT_GROUP_PERMISSION' ||
    'ACCESS_DENIED' => 'Bạn không có quyền tạo bình chọn trong hoạt động này.',
    'GROUP_ARCHIVED' => 'Nhóm đã lưu trữ nên không thể tạo bình chọn.',
    _ => 'Không thể tạo bình chọn.',
  };
}
