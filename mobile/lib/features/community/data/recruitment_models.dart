import '../../moments/data/moment_models.dart';

class RecruitmentView {
  final String groupId, groupName, status, requestState, broadLocation;
  final String? activityId, activityTitle, requestId;
  final int requested, approved, remaining;
  final List<String> tags;
  final DateTime? plannedAt;
  final DateTime expiresAt;
  final bool canRequest, canCancel, canManage;
  RecruitmentView(Json j)
    : groupId = j['groupId'] as String,
      groupName = j['groupName'] as String,
      status = j['status'] as String,
      requestState = j['requestState'] as String,
      broadLocation = j['broadLocation'] as String,
      activityId = j['activityId'] as String?,
      activityTitle = j['activityTitle'] as String?,
      requestId = j['requestId'] as String?,
      requested = (j['requestedCount'] as num).toInt(),
      approved = (j['approvedCount'] as num).toInt(),
      remaining = (j['remainingSlots'] as num).toInt(),
      tags = (j['tags'] as List).cast<String>(),
      plannedAt = j['plannedAt'] == null
          ? null
          : DateTime.parse(j['plannedAt'] as String),
      expiresAt = DateTime.parse(j['expiresAt'] as String),
      canRequest = j['canRequest'] == true,
      canCancel = j['canCancel'] == true,
      canManage = j['canManage'] == true;
}

const recruitmentStates = {
  'OPEN': 'Đang tuyển',
  'FILLED': 'Đã đủ người',
  'CLOSED': 'Đã đóng',
  'EXPIRED': 'Đã hết hạn',
};
const recruitmentRequests = {
  'NOT_REQUESTED': 'Chưa yêu cầu',
  'PENDING': 'Đang chờ duyệt',
  'MEMBER': 'Bạn là thành viên',
  'APPROVED': 'Đã được duyệt',
  'REJECTED': 'Yêu cầu bị từ chối',
  'CANCELLED': 'Đã hủy yêu cầu',
};
