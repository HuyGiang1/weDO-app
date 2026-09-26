import '../../../core/network/api_exception.dart';

enum GroupFailureType {
  validation,
  groupNotFound,
  memberNotFound,
  archived,
  insufficientPermission,
  transferRequired,
  invalidOwnershipTarget,
  invalidRoleTransition,
  groupDeleted,
  groupMemberLimitReached,
  userBannedFromGroup,
  invitationNotFound,
  invitationAlreadyResolved,
  inviteLinkNotFound,
  inviteLinkExpired,
  inviteLinkRevoked,
  inviteLinkLimitReached,
  joinRequestNotFound,
  joinRequestAlreadyPending,
  joinRequestAlreadyResolved,
  alreadyGroupMember,
  cannotInviteSelf,
  cannotBanSelf,
  cannotBanOwner,
  cannotBanAdmin,
  userAlreadyBanned,
  userNotBanned,
  network,
  unauthorized,
  unknown,
}

class GroupFailure {
  final GroupFailureType type;
  final Map<String, String> fieldErrors;
  const GroupFailure(this.type, {this.fieldErrors = const {}});
  factory GroupFailure.fromApi(ApiException e) {
    final t = switch (e.code) {
      'VALIDATION_FAILED' => GroupFailureType.validation,
      'GROUP_NOT_FOUND' => GroupFailureType.groupNotFound,
      'GROUP_MEMBER_NOT_FOUND' => GroupFailureType.memberNotFound,
      'GROUP_ARCHIVED' => GroupFailureType.archived,
      'GROUP_DELETED' => GroupFailureType.groupDeleted,
      'GROUP_MEMBER_LIMIT_REACHED' => GroupFailureType.groupMemberLimitReached,
      'USER_BANNED_FROM_GROUP' => GroupFailureType.userBannedFromGroup,
      'GROUP_INVITATION_NOT_FOUND' => GroupFailureType.invitationNotFound,
      'INVITATION_ALREADY_RESOLVED' => GroupFailureType.invitationAlreadyResolved,
      'INVITE_LINK_NOT_FOUND' => GroupFailureType.inviteLinkNotFound,
      'INVITE_LINK_EXPIRED' => GroupFailureType.inviteLinkExpired,
      'INVITE_LINK_REVOKED' => GroupFailureType.inviteLinkRevoked,
      'INVITE_LINK_LIMIT_REACHED' => GroupFailureType.inviteLinkLimitReached,
      'JOIN_REQUEST_NOT_FOUND' => GroupFailureType.joinRequestNotFound,
      'JOIN_REQUEST_ALREADY_PENDING' => GroupFailureType.joinRequestAlreadyPending,
      'JOIN_REQUEST_ALREADY_RESOLVED' => GroupFailureType.joinRequestAlreadyResolved,
      'ALREADY_GROUP_MEMBER' => GroupFailureType.alreadyGroupMember,
      'CANNOT_INVITE_SELF' => GroupFailureType.cannotInviteSelf,
      'CANNOT_BAN_SELF' => GroupFailureType.cannotBanSelf,
      'CANNOT_BAN_OWNER' => GroupFailureType.cannotBanOwner,
      'CANNOT_BAN_ADMIN' => GroupFailureType.cannotBanAdmin,
      'USER_ALREADY_BANNED' => GroupFailureType.userAlreadyBanned,
      'USER_NOT_BANNED' => GroupFailureType.userNotBanned,
      'INSUFFICIENT_GROUP_PERMISSION' =>
        GroupFailureType.insufficientPermission,
      'TRANSFER_OWNERSHIP_REQUIRED' => GroupFailureType.transferRequired,
      'INVALID_OWNERSHIP_TARGET' => GroupFailureType.invalidOwnershipTarget,
      'INVALID_GROUP_ROLE_TRANSITION' => GroupFailureType.invalidRoleTransition,
      _ =>
        e.transportFailure == ApiTransportFailure.network
            ? GroupFailureType.network
            : e.statusCode == 401
            ? GroupFailureType.unauthorized
            : GroupFailureType.unknown,
    };
    return GroupFailure(t, fieldErrors: e.fieldErrors);
  }

  String toVietnameseMessage() {
    return switch (type) {
      GroupFailureType.archived =>
        'Nhóm đã được lưu trữ và không thể chỉnh sửa.',
      GroupFailureType.insufficientPermission =>
        'Bạn không có quyền thực hiện thao tác này trong nhóm.',
      GroupFailureType.groupNotFound =>
        'Không tìm thấy nhóm.',
      GroupFailureType.groupDeleted =>
        'Nhóm này đã bị xóa.',
      GroupFailureType.memberNotFound =>
        'Không tìm thấy thành viên trong nhóm.',
      GroupFailureType.groupMemberLimitReached =>
        'Nhóm đã đạt số lượng thành viên tối đa.',
      GroupFailureType.userBannedFromGroup =>
        'Bạn đã bị chặn khỏi nhóm này.',
      GroupFailureType.inviteLinkExpired =>
        'Liên kết mời đã hết hạn.',
      GroupFailureType.inviteLinkRevoked =>
        'Liên kết mời đã bị thu hồi.',
      GroupFailureType.inviteLinkLimitReached =>
        'Liên kết mời đã hết lượt sử dụng.',
      GroupFailureType.network =>
        'Không thể kết nối mạng. Vui lòng kiểm tra lại.',
      GroupFailureType.unauthorized =>
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      _ => 'Thao tác không thành công. Vui lòng thử lại.',
    };
  }
}

class GroupException implements Exception {
  final GroupFailure failure;
  const GroupException(this.failure);
}
