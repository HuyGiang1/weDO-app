// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import 'discussion_models.dart';

class DiscussionApi {
  final Dio dio;
  DiscussionApi(this.dio);
  Future<ActivityDiscussion> list(String activityId) async {
    try {
      final data = (await dio.get<dynamic>(
        '/api/v1/activities/${Uri.encodeComponent(activityId)}/comments',
      )).data;
      if (data is! Map)
        throw const FormatException('Expected discussion response');
      return ActivityDiscussion.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<ActivityComment> _write(
    Future<Response<dynamic>> Function() call,
  ) async {
    try {
      final data = (await call()).data;
      if (data is! Map) throw const FormatException('Expected object response');
      return ActivityComment.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<ActivityComment> add(String activityId, String content) => _write(
    () => dio.post(
      '/api/v1/activities/${Uri.encodeComponent(activityId)}/comments',
      data: {'content': content},
    ),
  );
  Future<ActivityComment> reply(String id, String content) => _write(
    () => dio.post(
      '/api/v1/comments/${Uri.encodeComponent(id)}/replies',
      data: {'content': content},
    ),
  );
  Future<ActivityComment> update(String id, String content) => _write(
    () => dio.patch(
      '/api/v1/comments/${Uri.encodeComponent(id)}',
      data: {'content': content},
    ),
  );
  Future<void> delete(String id) async {
    try {
      await dio.delete('/api/v1/comments/${Uri.encodeComponent(id)}');
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
