import '../../../core/network/api_exception.dart';

class NotificationFailure implements Exception {
  final String code;
  final String message;
  final int? statusCode;

  const NotificationFailure({
    required this.code,
    required this.message,
    this.statusCode,
  });

  factory NotificationFailure.fromException(Object error) {
    if (error is NotificationFailure) return error;
    if (error is ApiException) {
      final String resolvedCode = error.code ?? 'API_ERROR';
      final String resolvedMessage = error.message ?? '';
      return NotificationFailure(
        code: resolvedCode,
        message: mapMessage(resolvedCode, resolvedMessage),
        statusCode: error.statusCode,
      );
    }
    return const NotificationFailure(
      code: 'UNKNOWN_ERROR',
      message: 'Đã xảy ra lỗi khi tải thông báo. Vui lòng thử lại.',
    );
  }

  static String mapMessage(String code, String fallback) {
    switch (code) {
      case 'NOTIFICATION_NOT_FOUND':
        return 'Không tìm thấy thông báo này hoặc bạn không có quyền truy cập.';
      case 'DEVICE_NOT_FOUND':
        return 'Không tìm thấy thiết bị đã đăng ký.';
      case 'GROUP_NOT_FOUND':
        return 'Không tìm thấy nhóm hoặc bạn không còn trong nhóm.';
      case 'ACCESS_DENIED':
        return 'Bạn không có quyền thực hiện thao tác này.';
      case 'VALIDATION_FAILED':
        return fallback.isNotEmpty
            ? fallback
            : 'Dữ liệu cài đặt thông báo không hợp lệ.';
      default:
        return fallback.isNotEmpty
            ? fallback
            : 'Đã xảy ra lỗi khi xử lý thông báo.';
    }
  }

  @override
  String toString() => message;
}
