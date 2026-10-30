import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../community/data/community_api.dart';
import '../../moments/data/moment_models.dart';

const stopStates = {
  'PLANNED': 'Dự kiến',
  'IN_PROGRESS': 'Đang diễn ra',
  'COMPLETED': 'Đã hoàn thành',
  'SKIPPED': 'Bỏ qua',
  'CANCELLED': 'Đã hủy',
};
const evidenceModes = {
  'NONE': 'Không bắt buộc ảnh',
  'DIRECT_COMPLETE': 'Gửi ảnh để hoàn thành',
  'REQUIRE_REVIEW': 'Gửi ảnh và chờ duyệt',
};
const evidenceStates = {
  'PENDING': 'Chờ duyệt',
  'APPROVED': 'Đã chấp nhận',
  'REJECTED': 'Cần chụp lại',
  'SUPERSEDED': 'Đã có thay đổi / minh chứng mới',
};

class JourneyApi extends CommunityApi {
  JourneyApi(super.dio, {super.uploads});
  // Check-ins reference canonical private Moment media, not Community posts.
  @override
  Future<String> mediaUrl(String id) => call(
    () => dio.get('/api/v1/moment-media/$id/access'),
    (j) => j['url'] as String,
  );
  String root(String activity) => '/api/v1/activities/$activity/journey';
  Future<Json> journey(String activity) =>
      call(() => dio.get(root(activity)), (j) => j);
  Future<Json> stop(String activity, String id) =>
      call(() => dio.get('${root(activity)}/stops/$id'), (j) => j);
  Future<Json> saveStop(String activity, Json data, {String? id}) => call(
    () => id == null
        ? dio.post('${root(activity)}/stops', data: data)
        : dio.patch('${root(activity)}/stops/$id', data: data),
    (j) => j,
  );
  Future<Json> order(String activity, List<String> old, List<String> ids) =>
      call(
        () => dio.put(
          '${root(activity)}/order',
          data: {'expectedOrder': old, 'orderedIds': ids},
        ),
        (j) => j,
      );
  Future<Json> state(String activity, Json stop, String status) => call(
    () => dio.put(
      '${root(activity)}/stops/${stop['id']}/status',
      data: {'status': status, 'expectedUpdatedAt': stop['updatedAt']},
    ),
    (j) => j,
  );
  Future<void> deleteStop(String activity, Json stop) => command(
    () => dio.delete(
      '${root(activity)}/stops/${stop['id']}',
      queryParameters: {'expectedUpdatedAt': stop['updatedAt']},
    ),
  );
  Future<Json> checkIns(String activity, String id, {String? before}) => call(
    () => dio.get(
      '${root(activity)}/stops/$id/checkins',
      queryParameters: {'before': ?before},
    ),
    (j) => j,
  );
  Future<Json> checkIn(String activity, String stop, Json data) => call(
    () => dio.post('${root(activity)}/stops/$stop/checkins', data: data),
    (j) => j,
  );
  Future<Json> execution(String task, {String? before}) => call(
    () => dio.get(
      '/api/v1/tasks/$task/execution',
      queryParameters: {'before': ?before},
    ),
    (j) => j,
  );
  Future<Json> configure(String task, String mode, String? stop) => call(
    () => dio.put(
      '/api/v1/tasks/$task/execution',
      data: {'mode': mode, 'stopId': stop},
    ),
    (j) => j,
  );
  Future<Json> evidence(String task, Json data) => call(
    () => dio.post('/api/v1/tasks/$task/evidence', data: data),
    (j) => j,
  );
  Future<Json> review(String task, String id, Json data) => call(
    () => dio.post('/api/v1/tasks/$task/evidence/$id/review', data: data),
    (j) => j,
  );
  Future<Json> pollActions(String id) =>
      call(() => dio.get('/api/v1/polls/$id/actions'), (j) => j);
  Future<Json> convert(String id, Json data) =>
      call(() => dio.post('/api/v1/polls/$id/actions', data: data), (j) => j);
  Future<List<Json>> list(String path) async {
    try {
      return ((await dio.get(path)).data as List)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

class EvidenceMediaApi extends JourneyApi {
  final String taskId;
  EvidenceMediaApi(super.dio, this.taskId);
  @override
  Future<String> mediaUrl(String id) => call(
    () => dio.get('/api/v1/tasks/$taskId/evidence/media/$id/access'),
    (j) => j['url'] as String,
  );
}
