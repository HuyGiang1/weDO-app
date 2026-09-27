import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/task/data/task_api.dart';
import 'package:mobile/features/task/data/task_models.dart';

void main() {
  test(
    'create forwards the exact activity id and valid task request',
    () async {
      final adapter = _TaskAdapter();
      final api = TaskApi(
        Dio(BaseOptions(baseUrl: 'https://test'))..httpClientAdapter = adapter,
      );
      final dueAt = DateTime(2030, 5, 1, 9, 30);

      final task = await api.create(
        'activity-123',
        ActivityTaskDraft(
          title: 'Bring drinks',
          description: 'For everyone',
          assigneeUserIds: const ['user-2', 'user-3'],
          dueAt: dueAt,
        ),
      );

      expect(adapter.request.path, '/api/v1/activities/activity-123/tasks');
      expect(adapter.request.method, 'POST');
      expect(adapter.request.data, {
        'title': 'Bring drinks',
        'description': 'For everyone',
        'assigneeUserIds': ['user-2', 'user-3'],
        'dueAt': dueAt.toUtc().toIso8601String(),
      });
      expect(task.activityId, 'activity-123');
      expect(task.statusHistory.single.fromStatus, isNull);
    },
  );

  test('status and delete use the canonical Task endpoints', () async {
    final adapter = _TaskAdapter();
    final api = TaskApi(
      Dio(BaseOptions(baseUrl: 'https://test'))..httpClientAdapter = adapter,
    );

    await api.updateStatus('task-1', ActivityTaskStatus.done);
    expect(adapter.request.method, 'PUT');
    expect(adapter.request.path, '/api/v1/tasks/task-1/status');
    expect(adapter.request.data, {'status': 'DONE'});

    await api.delete('task-1');
    expect(adapter.request.method, 'DELETE');
    expect(adapter.request.path, '/api/v1/tasks/task-1');
  });
}

class _TaskAdapter implements HttpClientAdapter {
  late RequestOptions request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    if (options.method == 'DELETE') {
      return ResponseBody.fromString('', 204);
    }
    return ResponseBody.fromString(
      jsonEncode({
        'id': 'task-1',
        'activityId': 'activity-123',
        'createdBy': 'user-1',
        'title': 'Bring drinks',
        'description': 'For everyone',
        'status': 'TODO',
        'dueAt': '2030-05-01T02:30:00Z',
        'assigneeUserIds': ['user-2', 'user-3'],
        'statusHistory': [
          {
            'fromStatus': null,
            'toStatus': 'TODO',
            'changedBy': 'user-1',
            'createdAt': '2030-05-01T02:00:00Z',
          },
        ],
        'permissions': {
          'canEdit': true,
          'canManageAssignees': true,
          'canClaim': false,
          'canChangeStatus': true,
        },
      }),
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
