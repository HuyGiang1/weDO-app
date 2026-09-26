import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/activity/data/activity_api.dart';
import 'package:mobile/features/activity/data/activity_models.dart';

void main() {
  late _TestAdapter adapter;
  late ActivityApi api;

  setUp(() {
    adapter = _TestAdapter();
    api = ActivityApi(
      Dio(BaseOptions(baseUrl: 'https://test'))..httpClientAdapter = adapter,
    );
  });

  final sampleDetailJson = {
    'id': 'act-1',
    'groupId': 'grp-1',
    'title': 'Test Activity',
    'status': 'PLANNING',
    'startAt': '2030-01-01T10:00:00Z',
    'timezone': 'Asia/Ho_Chi_Minh',
    'createdAt': '2030-01-01T00:00:00Z',
    'updatedAt': '2030-01-01T00:00:00Z',
    'creator': {'userId': 'u1'},
    'callerRsvpStatus': 'NO_RESPONSE',
    'goingCount': 0,
    'maybeCount': 0,
    'notGoingCount': 0,
    'waitlistCount': 0,
    'permissions': {
      'canEdit': true,
      'canConfirm': true,
      'canCancel': true,
      'canComplete': false,
      'canRsvp': true,
    },
  };

  test('list calls GET /api/v1/groups/{groupId}/activities with pagination', () async {
    adapter.data['/api/v1/groups/grp-1/activities'] = {
      'items': [
        {
          'id': 'act-1',
          'groupId': 'grp-1',
          'title': 'Test Activity',
          'status': 'PLANNING',
          'startAt': '2030-01-01T10:00:00Z',
          'timezone': 'Asia/Ho_Chi_Minh',
          'callerRsvpStatus': 'GOING',
          'goingCount': 5,
          'waitlistCount': 0,
        }
      ],
      'page': 0,
      'size': 30,
      'totalElements': 1,
      'totalPages': 1,
      'hasNext': false,
    };

    final result = await api.list('grp-1', page: 0, size: 30);
    final req = adapter.requests.single;

    expect(req.method, 'GET');
    expect(req.path, '/api/v1/groups/grp-1/activities');
    expect(req.queryParameters, {'page': 0, 'size': 30});
    expect(result.items.length, 1);
    expect(result.items.first.title, 'Test Activity');
  });

  test('create calls POST /api/v1/groups/{groupId}/activities with draft payload', () async {
    adapter.data['/api/v1/groups/grp-1/activities'] = sampleDetailJson;

    final draft = ActivityDraft(
      title: 'New Run',
      timezone: 'Asia/Ho_Chi_Minh',
      startAt: DateTime.utc(2030, 5, 1, 6, 0),
    );

    final result = await api.create('grp-1', draft);
    final req = adapter.requests.single;

    expect(req.method, 'POST');
    expect(req.path, '/api/v1/groups/grp-1/activities');
    expect(req.data['title'], 'New Run');
    expect(req.data['timezone'], 'Asia/Ho_Chi_Minh');
    expect(result.id, 'act-1');
  });

  test('detail calls GET /api/v1/activities/{id}', () async {
    adapter.data['/api/v1/activities/act-1'] = sampleDetailJson;

    final result = await api.detail('act-1');
    final req = adapter.requests.single;

    expect(req.method, 'GET');
    expect(req.path, '/api/v1/activities/act-1');
    expect(result.id, 'act-1');
    expect(result.permissions.canEdit, isTrue);
  });

  test('update calls PATCH /api/v1/activities/{id} with patch map', () async {
    adapter.data['/api/v1/activities/act-1'] = sampleDetailJson;

    final patch = {'title': 'Updated Title'};
    final result = await api.update('act-1', patch);
    final req = adapter.requests.single;

    expect(req.method, 'PATCH');
    expect(req.path, '/api/v1/activities/act-1');
    expect(req.data, {'title': 'Updated Title'});
    expect(result.id, 'act-1');
  });

  test('confirm calls POST /api/v1/activities/{id}/confirm', () async {
    adapter.data['/api/v1/activities/act-1/confirm'] = sampleDetailJson;

    final result = await api.confirm('act-1');
    final req = adapter.requests.single;

    expect(req.method, 'POST');
    expect(req.path, '/api/v1/activities/act-1/confirm');
    expect(result.id, 'act-1');
  });

  test('cancel calls POST /api/v1/activities/{id}/cancel with optional reason', () async {
    adapter.data['/api/v1/activities/act-1/cancel'] = sampleDetailJson;

    final result = await api.cancel('act-1', reason: 'Bad weather');
    final req = adapter.requests.single;

    expect(req.method, 'POST');
    expect(req.path, '/api/v1/activities/act-1/cancel');
    expect(req.data, {'reason': 'Bad weather'});
    expect(result.id, 'act-1');
  });

  test('complete calls POST /api/v1/activities/{id}/complete', () async {
    adapter.data['/api/v1/activities/act-1/complete'] = sampleDetailJson;

    final result = await api.complete('act-1');
    final req = adapter.requests.single;

    expect(req.method, 'POST');
    expect(req.path, '/api/v1/activities/act-1/complete');
    expect(result.id, 'act-1');
  });

  test('rsvp calls PUT /api/v1/activities/{id}/rsvp with wire status', () async {
    adapter.data['/api/v1/activities/act-1/rsvp'] = {
      'activityId': 'act-1',
      'userId': 'u1',
      'status': 'GOING',
      'waitlistSequence': null,
      'effectiveLifecycleStatus': 'PLANNING',
    };

    final result = await api.rsvp('act-1', ActivityRsvpStatus.going);
    final req = adapter.requests.single;

    expect(req.method, 'PUT');
    expect(req.path, '/api/v1/activities/act-1/rsvp');
    expect(req.data, {'status': 'GOING'});
    expect(result.status, ActivityRsvpStatus.going);
  });

  test('participants calls GET /api/v1/activities/{id}/participants', () async {
    adapter.data['/api/v1/activities/act-1/participants'] = [
      {
        'userId': 'u1',
        'username': 'runner1',
        'displayName': 'Runner One',
        'status': 'GOING',
        'createdAt': '2030-01-01T00:00:00Z',
      },
    ];

    final result = await api.participants('act-1');
    final req = adapter.requests.single;

    expect(req.method, 'GET');
    expect(req.path, '/api/v1/activities/act-1/participants');
    expect(result.length, 1);
    expect(result.first.username, 'runner1');
  });
}

class _TestAdapter implements HttpClientAdapter {
  final data = <String, dynamic>{};
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final body = data[options.path];
    return ResponseBody.fromString(
      jsonEncode(body ?? {}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
