import 'poll_api.dart';
import 'poll_models.dart';

class PollRepository {
  final PollApi api;
  PollRepository(this.api);
  Future<List<Poll>> list(String activityId) => api.list(activityId);
  Future<Poll> get(String id) => api.get(id);
  Future<Poll> create(String activityId, CreatePollDraft d) =>
      api.create(activityId, d);
  Future<Poll> vote(String id, List<String> ids) => api.vote(id, ids);
  Future<Poll> addOption(String id, String text) => api.addOption(id, text);
  Future<Poll> updateOption(String p, String o, String text) =>
      api.updateOption(p, o, text);
  Future<void> deleteOption(String p, String o) => api.deleteOption(p, o);
  Future<Poll> disableOption(String p, String o) => api.disableOption(p, o);
  Future<Poll> close(String id) => api.close(id);
  Future<List<PollVoters>> voters(String id) => api.voters(id);
}
