import '../../features/activity/data/activity_models.dart';
import '../../features/groups/data/models/group_models.dart';
import '../../features/privacy/data/privacy_models.dart';
import 'app_strings.dart';

extension ActivityStatusLabel on ActivityStatus {
  String get label => switch (this) {
    ActivityStatus.planning => AppStrings.statusPlanning,
    ActivityStatus.confirmed => AppStrings.statusConfirmed,
    ActivityStatus.inProgress => AppStrings.statusInProgress,
    ActivityStatus.completed => AppStrings.statusCompleted,
    ActivityStatus.cancelled => AppStrings.statusCancelled,
  };
}

extension GroupRoleLabel on GroupRole {
  String get label => switch (this) {
    GroupRole.owner => 'Chủ nhóm',
    GroupRole.admin => 'Quản trị viên',
    GroupRole.member => 'Thành viên',
  };
}

extension GroupStatusLabel on GroupStatus {
  String get label => switch (this) {
    GroupStatus.active => 'Đang hoạt động',
    GroupStatus.archived => 'Đã lưu trữ',
    GroupStatus.deleted => 'Đã xóa',
  };
}

extension DmPolicyLabel on DmPolicy {
  String get label => switch (this) {
    DmPolicy.everyone => 'Mọi người',
    DmPolicy.mutualGroups => 'Người chung nhóm',
    DmPolicy.friendsOnly => 'Chỉ bạn bè',
  };
}

extension FriendRequestPolicyLabel on FriendRequestPolicy {
  String get label => switch (this) {
    FriendRequestPolicy.everyone => 'Mọi người',
    FriendRequestPolicy.mutualGroups => 'Người chung nhóm',
    FriendRequestPolicy.none => 'Không ai',
  };
}
