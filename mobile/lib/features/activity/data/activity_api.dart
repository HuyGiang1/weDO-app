import 'package:dio/dio.dart';

import '../../../core/models/paged_response.dart';
import '../../../core/network/api_exception.dart';
import 'activity_models.dart';

class ActivityApi {
  final Dio dio;
  ActivityApi(this.dio);
  Future<T> _map<T>(
    Future<Response<dynamic>> Function() call,
    T Function(Map<String, dynamic>) parser,
  ) async {
    try {
      final data = (await call()).data;
      if (data is! Map) throw const FormatException('Expected JSON object');
      return parser(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<T>> _list<T>(
    Future<Response<dynamic>> Function() call,
    T Function(Map<String, dynamic>) parser,
  ) async {
    try {
      final data = (await call()).data;
      if (data is! List) throw const FormatException('Expected JSON list');
      return data.map((e) {
        if (e is! Map) throw const FormatException('Expected JSON object');
        return parser(Map<String, dynamic>.from(e));
      }).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<PagedResponse<ActivitySummary>> list(
    String groupId, {
    int page = 0,
    int size = 30,
  }) => _map(
    () => dio.get(
      '/api/v1/groups/${Uri.encodeComponent(groupId)}/activities',
      queryParameters: {'page': page, 'size': size},
    ),
    (j) => PagedResponse.fromJson(j, ActivitySummary.fromJson),
  );
  Future<ActivityDetail> create(String groupId, ActivityDraft request) => _map(
    () => dio.post(
      '/api/v1/groups/${Uri.encodeComponent(groupId)}/activities',
      data: request.toCreateJson(),
    ),
    ActivityDetail.fromJson,
  );
  Future<ActivityDetail> detail(String id) => _map(
    () => dio.get('/api/v1/activities/${Uri.encodeComponent(id)}'),
    ActivityDetail.fromJson,
  );
  Future<ActivityDetail> update(String id, Map<String, dynamic> request) =>
      _map(
        () => dio.patch(
          '/api/v1/activities/${Uri.encodeComponent(id)}',
          data: request,
        ),
        ActivityDetail.fromJson,
      );
  Future<ActivityDetail> confirm(String id) => _map(
    () => dio.post('/api/v1/activities/${Uri.encodeComponent(id)}/confirm'),
    ActivityDetail.fromJson,
  );
  Future<ActivityDetail> cancel(String id, {String? reason}) => _map(
    () => dio.post(
      '/api/v1/activities/${Uri.encodeComponent(id)}/cancel',
      data: reason == null ? null : {'reason': reason},
    ),
    ActivityDetail.fromJson,
  );
  Future<ActivityDetail> complete(String id) => _map(
    () => dio.post('/api/v1/activities/${Uri.encodeComponent(id)}/complete'),
    ActivityDetail.fromJson,
  );
  Future<ActivityRsvp> rsvp(String id, ActivityRsvpStatus status) => _map(
    () => dio.put(
      '/api/v1/activities/${Uri.encodeComponent(id)}/rsvp',
      data: {'status': status.wire},
    ),
    ActivityRsvp.fromJson,
  );
  Future<List<ActivityParticipant>> participants(String id) => _list(
    () => dio.get('/api/v1/activities/${Uri.encodeComponent(id)}/participants'),
    ActivityParticipant.fromJson,
  );
}
