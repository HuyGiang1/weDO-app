import '../../../core/network/api_exception.dart';

String createTaskFailureMessage(Object error) {
  if (error is! ApiException) return 'Không thể tạo công việc.';

  if (error.transportFailure == ApiTransportFailure.network) {
    return 'Không thể kết nối đến máy chủ. Vui lòng thử lại.';
  }
  if (error.transportFailure == ApiTransportFailure.timeout) {
    return 'Kết nối đến máy chủ quá lâu. Vui lòng thử lại.';
  }

  return switch (error.code) {
    'VALIDATION_FAILED' =>
      'Thông tin công việc chưa hợp lệ. Kiểm tra tiêu đề và hạn hoàn thành.',
    'GROUP_MEMBER_NOT_FOUND' =>
      'Người được giao không còn là thành viên hoạt động của nhóm.',
    'ACTIVITY_CLOSED' ||
    'ACTIVITY_ALREADY_COMPLETED' ||
    'GROUP_ARCHIVED' => 'Hoạt động hoặc nhóm không còn cho phép tạo công việc.',
    'INSUFFICIENT_GROUP_PERMISSION' ||
    'ACCESS_DENIED' => 'Bạn không có quyền tạo công việc trong hoạt động này.',
    _ => 'Không thể tạo công việc.',
  };
}
