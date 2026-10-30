import 'task_api.dart';
import 'task_models.dart';
import '../../activity/data/activity_api.dart';
import '../../activity/data/activity_models.dart';
import '../../groups/data/group_api.dart';
import '../../groups/data/models/group_models.dart';

class TaskRepository {
  final TaskApi api;
  TaskRepository(this.api);
  Future<List<GroupMember>> eligibleAssignees(String activityId) async {
    final activities = ActivityApi(api.dio);
    final detail = await activities.detail(activityId);
    final participants = await activities.participants(activityId);
    final eligibleIds = participants
        .where((p) => p.rsvpStatus == ActivityRsvpStatus.going)
        .map((p) => p.userId)
        .toSet();
    final members = await GroupApi(api.dio).getMembers(detail.groupId);
    return members.where((m) => eligibleIds.contains(m.userId)).toList();
  }

  Future<List<ActivityTask>> list(
    String activityId, {
    ActivityTaskStatus? status,
    bool? assignedToMe,
  }) => api.list(activityId, status: status, assignedToMe: assignedToMe);
  Future<ActivityTask> get(String id) => api.get(id);
  Future<ActivityTask> create(String activityId, ActivityTaskDraft draft) =>
      api.create(activityId, draft);
  Future<ActivityTask> update(String id, ActivityTaskDraft draft) =>
      api.update(id, draft);
  Future<ActivityTask> updateStatus(String id, ActivityTaskStatus status) =>
      api.updateStatus(id, status);
  Future<ActivityTask> claim(String id) => api.claim(id);
  Future<void> delete(String id) => api.delete(id);
}
