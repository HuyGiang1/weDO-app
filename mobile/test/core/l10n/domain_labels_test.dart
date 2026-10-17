import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/l10n/domain_labels.dart';
import 'package:mobile/features/activity/data/activity_models.dart';
import 'package:mobile/features/groups/data/models/group_models.dart';
import 'package:mobile/features/privacy/data/privacy_models.dart';

void main() {
  test('Vietnamese role/status labels do not change wire values', () {
    expect(GroupRole.values.map((v) => v.label), [
      'Chủ nhóm',
      'Quản trị viên',
      'Thành viên',
    ]);
    expect(GroupRole.values.map((v) => v.wireValue), [
      'OWNER',
      'ADMIN',
      'MEMBER',
    ]);
    expect(GroupStatus.active.label, 'Đang hoạt động');
    expect(GroupStatus.archived.label, 'Đã lưu trữ');
    expect(GroupStatus.deleted.label, 'Đã xóa');
    expect(ActivityStatus.values.map((v) => v.label), [
      'Đang lên kế hoạch',
      'Đã xác nhận',
      'Đang diễn ra',
      'Đã hoàn thành',
      'Đã hủy',
    ]);
    expect(ActivityStatus.values.map((v) => v.wire), [
      'PLANNING',
      'CONFIRMED',
      'IN_PROGRESS',
      'COMPLETED',
      'CANCELLED',
    ]);
  });

  test('privacy labels keep distinct server policies', () {
    expect(DmPolicy.values.map((v) => v.label), [
      'Mọi người',
      'Người chung nhóm',
      'Chỉ bạn bè',
    ]);
    expect(FriendRequestPolicy.values.map((v) => v.label), [
      'Mọi người',
      'Người chung nhóm',
      'Không ai',
    ]);
    expect(DmPolicy.friendsOnly.wireValue, 'FRIENDS_ONLY');
    expect(FriendRequestPolicy.none.wireValue, 'NONE');
  });
}
