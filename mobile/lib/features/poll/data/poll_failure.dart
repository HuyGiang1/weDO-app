import '../../../core/network/api_exception.dart';

String votePollFailureMessage(ApiException error) {
  if (error.statusCode == 401) return 'Cần đăng nhập lại để bình chọn.';
  if (error.statusCode == 403 || error.statusCode == 404) {
    return 'Bạn không có quyền truy cập bình chọn này.';
  }
  if (error.transportFailure == ApiTransportFailure.network ||
      error.transportFailure == ApiTransportFailure.timeout) {
    return 'Không thể kết nối đến máy chủ. Bình chọn chưa được xác nhận. Vui lòng thử lại.';
  }
  return switch (error.code) {
    'POLL_CLOSED' ||
    'POLL_DEADLINE_PASSED' => 'Bình chọn đã đóng hoặc hết hạn.',
    'POLL_OPTION_DISABLED' =>
      'Lựa chọn này đã bị vô hiệu hóa. Vui lòng chọn lại.',
    'INVALID_POLL_SELECTION' || 'MAX_POLL_SELECTIONS_EXCEEDED' =>
      'Lựa chọn bình chọn không hợp lệ. Vui lòng chọn lại.',
    'GROUP_ARCHIVED' ||
    'ACTIVITY_CLOSED' => 'Hoạt động đã khóa, không thể cập nhật bình chọn.',
    _ => 'Không thể cập nhật bình chọn. Vui lòng thử lại.',
  };
}

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
