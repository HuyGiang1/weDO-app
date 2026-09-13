import '../../data/social_failure.dart';

/// Provides user-friendly localized error messages for social failures.
abstract final class SocialErrorLocalizer {
  static String localize(SocialFailure failure) {
    // If backend provided a specific code, prioritize specific domain guidance
    switch (failure.type) {
      case SocialFailureType.cannotFriendSelf:
        return 'Không thể gửi lời mời kết bạn cho chính mình.';
      case SocialFailureType.cannotBlockSelf:
        return 'Không thể chặn chính mình.';
      case SocialFailureType.userBlocked:
        return 'Không thể tương tác vì người dùng đã bị chặn.';
      case SocialFailureType.alreadyFriends:
        return 'Hai bạn đã là bạn bè.';
      case SocialFailureType.friendRequestAlreadyPending:
        return 'Lời mời kết bạn đã được gửi và đang chờ phản hồi.';
      case SocialFailureType.friendRequestCooldownActive:
        return 'Vui lòng đợi trước khi gửi lại lời mời kết bạn (thời gian chờ 24 giờ).';
      case SocialFailureType.friendRequestNotAllowed:
        return 'Cài đặt quyền riêng tư của người dùng không cho phép nhận lời mời kết bạn.';
      case SocialFailureType.friendRequestNotFound:
        return 'Không tìm thấy lời mời kết bạn.';
      case SocialFailureType.friendshipNotFound:
        return 'Không tìm thấy quan hệ bạn bè.';
      case SocialFailureType.resourceNotFound:
        return 'Người dùng không tồn tại hoặc tài khoản đã bị vô hiệu hóa.';
      case SocialFailureType.accessDenied:
        return 'Bạn không có quyền thực hiện hành động này.';
      case SocialFailureType.conflict:
        return 'Trạng thái đã thay đổi. Vui lòng làm mới trang và thử lại.';
      case SocialFailureType.authTokenExpired:
      case SocialFailureType.authTokenInvalid:
        return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
      case SocialFailureType.network:
        return 'Không có kết nối mạng. Vui lòng kiểm tra lại đường truyền internet.';
      case SocialFailureType.timeout:
        return 'Hết thời gian kết nối đến máy chủ. Vui lòng thử lại sau.';
      case SocialFailureType.unexpected:
        return failure.backendMessage ?? 'Đã có lỗi xảy ra. Vui lòng thử lại sau.';
    }
  }
}
