import '../../../core/models/paged_response.dart';
import '../../../core/network/api_exception.dart';
import 'activity_api.dart';
import 'activity_failure.dart';
import 'activity_models.dart';

class ActivityRepository {
  final ActivityApi api;
  ActivityRepository({required this.api});
  Future<T> _guard<T>(Future<T> Function() work) async {
    try {
      return await work();
    } on ApiException catch (e) {
      throw ActivityException(ActivityFailure.fromApi(e));
    } catch (e) {
      if (e is ActivityException) rethrow;
      throw const ActivityException(
        ActivityFailure(ActivityFailureType.unknown),
      );
    }
  }

  Future<PagedResponse<ActivitySummary>> list(
    String groupId, {
    int page = 0,
    int size = 30,
  }) => _guard(() => api.list(groupId, page: page, size: size));
  Future<ActivityDetail> create(String groupId, ActivityDraft d) =>
      _guard(() => api.create(groupId, d));
  Future<ActivityDetail> detail(String id) => _guard(() => api.detail(id));
  Future<ActivityDetail> update(String id, Map<String, dynamic> d) =>
      _guard(() => api.update(id, d));
  Future<ActivityDetail> confirm(String id) => _guard(() => api.confirm(id));
  Future<ActivityDetail> cancel(String id, {String? reason}) =>
      _guard(() => api.cancel(id, reason: reason));
  Future<ActivityDetail> complete(String id) => _guard(() => api.complete(id));
  Future<ActivityRsvp> rsvp(String id, ActivityRsvpStatus s) =>
      _guard(() => api.rsvp(id, s));
  Future<List<ActivityParticipant>> participants(String id) =>
      _guard(() => api.participants(id));
}
