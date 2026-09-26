/// Centralized Vietnamese-first UI strings and business error messages for weDO.
class AppStrings {
  const AppStrings._();

  // Common actions
  static const String confirm = 'Xác nhận';
  static const String cancel = 'Hủy';
  static const String save = 'Lưu';
  static const String delete = 'Xóa';
  static const String back = 'Quay lại';
  static const String retry = 'Thử lại';
  static const String close = 'Đóng';
  static const String copy = 'Sao chép';
  static const String copied = 'Đã sao chép vào bộ nhớ tạm';
  static const String share = 'Chia sẻ';
  static const String success = 'Thành công';
  static const String error = 'Lỗi';

  // Groups startup
  static const String groupsLoading = 'Đang tải nhóm...';
  static const String groupsLoadFailed =
      'Không thể tải danh sách nhóm. Vui lòng thử lại.';
  static const String myGroups = 'Nhóm của tôi';
  static const String myGroupsSubtitle =
      'Những không gian bạn đang cùng mọi người kết nối.';
  static const String createGroup = 'Tạo nhóm';
  static const String noGroups = 'Chưa có nhóm nào';
  static const String joinByCode = 'Tham gia bằng mã';
  static const String invitations = 'Lời mời';
  static const String createGroupTitle = 'Tạo nhóm mới';
  static const String createGroupDescription =
      'Bắt đầu không gian riêng cho hội bạn của bạn.';
  static const String groupImageUnavailable =
      'Tải ảnh nhóm hiện chưa khả dụng.';
  static const String groupNameLabel = 'Tên nhóm *';
  static const String groupNameRequired = 'Tên nhóm là bắt buộc';
  static const String groupDescriptionOptional = 'Mô tả (Tùy chọn)';
  static const String creatingGroup = 'Đang tạo...';

  // Group permission & status errors
  static const String groupArchivedCannotMutate =
      'Nhóm đã được lưu trữ và không thể chỉnh sửa.';
  static const String groupOnlyOwnerCanChangeSettings =
      'Chỉ trưởng nhóm mới có quyền thay đổi cài đặt này.';
  static const String groupPermissionDenied =
      'Bạn không có quyền thực hiện thao tác này trong nhóm.';
  static const String groupNotFound = 'Không tìm thấy nhóm.';
  static const String groupActionFailed =
      'Thao tác không thành công. Vui lòng thử lại.';

  // Group Info & Lifecycle
  static const String archiveGroup = 'Lưu trữ nhóm';
  static const String restoreGroup = 'Khôi phục nhóm';
  static const String archiveGroupConfirmTitle = 'Lưu trữ nhóm này?';
  static const String archiveGroupConfirmMessage =
      'Khi lưu trữ, các hoạt động và cài đặt của nhóm sẽ ở trạng thái chỉ đọc. Bạn có thể khôi phục lại bất kỳ lúc nào.';
  static const String restoreGroupConfirmTitle = 'Khôi phục nhóm?';
  static const String restoreGroupConfirmMessage =
      'Nhóm sẽ hoạt động trở lại bình thường và các thành viên có thể tiếp tục tạo hoạt động.';
  static const String groupArchivedBanner =
      'Nhóm này đang được lưu trữ. Mọi tính năng chỉnh sửa tạm thời bị khóa.';

  // Invite Links
  static const String groupInviteLinkTitle = 'Liên kết mời nhóm';
  static const String groupInviteLinkSubtitle =
      'Bất kỳ ai có liên kết này đều có thể tham gia nhóm.';
  static const String copyInviteLink = 'Sao chép liên kết';
  static const String shareInviteLink = 'Chia sẻ liên kết';
  static const String advancedInviteLinks = 'Quản lý liên kết nâng cao';
  static const String createCustomInviteLink = 'Tạo liên kết tùy chỉnh';
  static const String noActiveInviteLink = 'Chưa có liên kết mời. Đang tạo...';

  // Activities
  static const String activities = 'Hoạt động';
  static const String createActivity = 'Tạo hoạt động';
  static const String editActivity = 'Chỉnh sửa hoạt động';
  static const String activityTitleLabel = 'Tên hoạt động';
  static const String activityTitleHint =
      'Ví dụ: Cầu lông chiều thứ 7, Đi ăn lẩu...';
  static const String activityDescLabel = 'Mô tả chi tiết';
  static const String activityDescHint =
      'Thêm ghi chú, lịch trình hoặc dặn dò...';
  static const String scheduleSwitch = 'Lên lịch';
  static const String locationSwitch = 'Thêm địa điểm';
  static const String advancedOptions = 'Tùy chọn nâng cao';
  static const String maxParticipantsLabel = 'Số người tối đa';
  static const String maxParticipantsHint = 'Để trống nếu không giới hạn';
  static const String unscheduled = 'Chưa lên lịch';
  static const String unlimitedCapacity = 'Không giới hạn';

  // Activity Statuses
  static const String statusPlanning = 'Đang lên kế hoạch';
  static const String statusConfirmed = 'Đã xác nhận';
  static const String statusInProgress = 'Đang diễn ra';
  static const String statusCompleted = 'Đã hoàn thành';
  static const String statusCancelled = 'Đã hủy';

  // Activity participation
  static const String rsvpGoing = 'Tham gia';
  static const String rsvpInterested = 'Có thể tham gia';
  static const String rsvpNotGoing = 'Không tham gia';
  static const String participationStatus = 'Trạng thái tham gia của bạn';
  static const String changeParticipationStatus =
      'Thay đổi trạng thái tham gia';
  static const String participationUpdateFailed =
      'Không thể cập nhật trạng thái tham gia. Hoạt động có thể đã bị khóa hoặc hết chỗ.';
  static const String participantsCount = 'người tham gia';
  static const String viewParticipants = 'Xem danh sách người tham gia';

  // Group Activity Log
  static const String groupLogTitle = 'Nhật ký nhóm';
  static const String groupLogEmpty = 'Chưa có hoạt động nào được ghi nhận.';
  static const String actionActivityCreated = 'đã tạo hoạt động';
  static const String actionActivityConfirmed = 'đã chốt hoạt động';
  static const String actionActivityUpdated = 'đã cập nhật thông tin hoạt động';
  static const String actionActivityCancelled = 'đã hủy hoạt động';
  static const String actionActivityCompleted = 'đã hoàn thành hoạt động';
}
