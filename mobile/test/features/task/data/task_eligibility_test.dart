import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/task/data/task_api.dart';
import 'package:mobile/features/task/data/task_repository.dart';

class _Adapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    final Object data;
    if (request.path.endsWith('/participants')) {
      data = [
        for (final state in [
          'GOING',
          'MAYBE',
          'WAITLIST',
          'NOT_GOING',
          'NO_RESPONSE',
        ])
          {'userId': state, 'rsvpStatus': state},
        {'userId': 'removed', 'rsvpStatus': 'GOING'},
      ];
    } else if (request.path.endsWith('/members')) {
      data = [
        for (final state in [
          'GOING',
          'MAYBE',
          'WAITLIST',
          'NOT_GOING',
          'NO_RESPONSE',
        ])
          {
            'userId': state,
            'username': state,
            'displayName': state,
            'role': 'MEMBER',
            'joinedAt': '2030-01-01T00:00:00Z',
          },
      ];
    } else {
      data = {
        'id': 'a',
        'groupId': 'g',
        'title': 'Activity',
        'status': 'PLANNING',
        'startAt': null,
        'createdAt': '2030-01-01T00:00:00Z',
        'updatedAt': '2030-01-01T00:00:00Z',
        'creator': {'userId': 'owner'},
        'callerRsvpStatus': 'NO_RESPONSE',
        'goingCount': 2,
        'maybeCount': 1,
        'notGoingCount': 1,
        'waitlistCount': 1,
        'permissions': <String, Object>{},
      };
    }
    return ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  test('eligible assignees are GOING intersect active group members', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://test'))
      ..httpClientAdapter = _Adapter();
    final eligible = await TaskRepository(TaskApi(dio)).eligibleAssignees('a');
    expect(eligible.map((m) => m.userId), ['GOING']);
  });
}
