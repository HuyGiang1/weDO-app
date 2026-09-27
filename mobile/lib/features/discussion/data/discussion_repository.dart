import 'discussion_api.dart';
import 'discussion_models.dart';

class DiscussionRepository {
  final DiscussionApi api;
  DiscussionRepository(this.api);
  Future<ActivityDiscussion> list(String activityId) => api.list(activityId);
  Future<ActivityComment> add(String activityId, String content) =>
      api.add(activityId, content);
  Future<ActivityComment> reply(String id, String content) =>
      api.reply(id, content);
  Future<ActivityComment> update(String id, String content) =>
      api.update(id, content);
  Future<void> delete(String id) => api.delete(id);
}
