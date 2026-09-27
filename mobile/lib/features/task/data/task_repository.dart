import 'task_api.dart';
import 'task_models.dart';

class TaskRepository {
  final TaskApi api;
  TaskRepository(this.api);
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
