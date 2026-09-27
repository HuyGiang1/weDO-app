// ignore_for_file: use_null_aware_elements, curly_braces_in_flow_control_structures

import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import 'task_models.dart';

class TaskApi {
  final Dio dio;
  TaskApi(this.dio);

  Future<T> _object<T>(
    Future<Response<dynamic>> Function() call,
    T Function(Map<String, dynamic>) parse,
  ) async {
    try {
      final data = (await call()).data;
      if (data is! Map) throw const FormatException('Expected object response');
      return parse(Map<String, dynamic>.from(data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<ActivityTask>> list(
    String activityId, {
    ActivityTaskStatus? status,
    bool? assignedToMe,
  }) async {
    try {
      final response = await dio.get<dynamic>(
        '/api/v1/activities/${Uri.encodeComponent(activityId)}/tasks',
        queryParameters: {
          if (status != null) 'status': status.wire,
          if (assignedToMe != null) 'assignedToMe': assignedToMe,
        },
      );
      if (response.data is! List)
        throw const FormatException('Expected list response');
      return (response.data as List)
          .map(
            (item) =>
                ActivityTask.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<ActivityTask> get(String taskId) => _object(
    () => dio.get('/api/v1/tasks/${Uri.encodeComponent(taskId)}'),
    ActivityTask.fromJson,
  );
  Future<ActivityTask> create(String activityId, ActivityTaskDraft draft) =>
      _object(
        () => dio.post(
          '/api/v1/activities/${Uri.encodeComponent(activityId)}/tasks',
          data: draft.toJson(),
        ),
        ActivityTask.fromJson,
      );
  Future<ActivityTask> update(String taskId, ActivityTaskDraft draft) =>
      _object(
        () => dio.patch(
          '/api/v1/tasks/${Uri.encodeComponent(taskId)}',
          data: draft.toJson(),
        ),
        ActivityTask.fromJson,
      );
  Future<ActivityTask> updateStatus(String taskId, ActivityTaskStatus status) =>
      _object(
        () => dio.put(
          '/api/v1/tasks/${Uri.encodeComponent(taskId)}/status',
          data: {'status': status.wire},
        ),
        ActivityTask.fromJson,
      );
  Future<ActivityTask> claim(String taskId) => _object(
    () => dio.post('/api/v1/tasks/${Uri.encodeComponent(taskId)}/claim'),
    ActivityTask.fromJson,
  );
  Future<void> delete(String taskId) async {
    try {
      await dio.delete('/api/v1/tasks/${Uri.encodeComponent(taskId)}');
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
