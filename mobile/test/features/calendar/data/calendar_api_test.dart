import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/data/calendar_api.dart';
import 'package:mobile/features/calendar/data/calendar_models.dart';

void main() {
  late _Adapter adapter;
  late CalendarApi api;

  setUp(() {
    adapter = _Adapter();
    api = CalendarApi(
      Dio(BaseOptions(baseUrl: 'https://test'))..httpClientAdapter = adapter,
    );
  });

  test('calendar request serializes range and optional filters', () async {
    adapter.response = [_calendarActivity];
    final result = await api.activities(
      from: DateTime.utc(2026, 9, 1),
      to: DateTime.utc(2026, 9, 30),
      rsvp: 'GOING',
      groupId: 'group-1',
      status: 'CONFIRMED',
    );

    expect(adapter.request.path, '/api/v1/calendar/activities');
    expect(adapter.request.queryParameters, {
      'from': '2026-09-01T00:00:00.000Z',
      'to': '2026-09-30T00:00:00.000Z',
      'rsvp': 'GOING',
      'groupId': 'group-1',
      'status': 'CONFIRMED',
    });
    expect(result.single.id, 'activity-1');
    expect(result.single.reminderEnabled, isTrue);
    expect(result.single.callerRsvpStatus.name, 'going');
  });

  test('reminder update sends enabled and offset minutes', () async {
    adapter.response = {
      'activityId': 'activity-1',
      'configured': true,
      'enabled': true,
      'offsetMinutes': 30,
      'remindAt': '2026-09-30T08:30:00Z',
      'sentAt': null,
      'canConfigure': true,
      'unavailableReason': null,
    };
    final result = await api.updateReminder(
      'activity-1',
      enabled: true,
      offsetMinutes: 30,
    );

    expect(adapter.request.method, 'PUT');
    expect(adapter.request.path, '/api/v1/activities/activity-1/reminder');
    expect(adapter.request.data, {'enabled': true, 'offsetMinutes': 30});
    expect(result.offsetMinutes, 30);
    expect(result.canConfigure, isTrue);
  });

  test('UTC range formatting contains exactly one zone suffix', () {
    expect(
      offsetDateTimeQuery(DateTime.utc(2026, 9, 1)),
      '2026-09-01T00:00:00.000Z',
    );
  });
}

final _calendarActivity = <String, dynamic>{
  'id': 'activity-1',
  'groupId': 'group-1',
  'groupName': 'Cycling',
  'title': 'Morning ride',
  'status': 'CONFIRMED',
  'startAt': '2026-09-12T06:00:00Z',
  'endAt': null,
  'timezone': 'Asia/Ho_Chi_Minh',
  'locationName': 'Park',
  'goingCount': 3,
  'waitlistCount': 0,
  'callerRsvpStatus': 'GOING',
  'reminderEnabled': true,
  'reminderAt': '2026-09-12T05:45:00Z',
};

class _Adapter implements HttpClientAdapter {
  late RequestOptions request;
  dynamic response = <dynamic>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode(response),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
