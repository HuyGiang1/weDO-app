import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/notification/data/notification_api.dart';

void main() {
  late _RecordingAdapter adapter;
  late NotificationApi api;

  setUp(() {
    adapter = _RecordingAdapter();
    api = NotificationApi(
      Dio(BaseOptions(baseUrl: 'https://test'))..httpClientAdapter = adapter,
    );
  });

  test(
    'sends backend group mute fields and parses its response shape',
    () async {
      adapter.response = <String, dynamic>{
        'groupId': 'group-1',
        'muted': true,
        'effectivelyMuted': true,
        'muteOption': 'TIMED',
        'mutedUntil': '2026-09-29T13:00:00Z',
        'updatedAt': '2026-09-29T12:00:00Z',
      };

      final result = await api.updateGroupNotificationSettings(
        groupId: 'group-1',
        isMuted: true,
        muteDuration: '8h',
      );

      expect(adapter.request.method, 'PUT');
      expect(
        adapter.request.path,
        '/api/v1/groups/group-1/notification-settings',
      );
      expect(adapter.request.data, {'muted': true, 'duration': '8h'});
      expect(result.isMuted, isTrue);
      expect(result.muteDuration, 'TIMED');
      expect(result.muteUntil, DateTime.parse('2026-09-29T13:00:00Z'));
    },
  );

  test(
    'device registration sends only fields accepted by its backend DTO',
    () async {
      adapter.response = <String, dynamic>{
        'id': 'device-row-1',
        'userId': 'user-1',
        'deviceId': 'phone-1',
        'platform': 'ANDROID',
        'pushToken': 'native-token',
        'active': true,
      };

      await api.registerDevice(
        deviceId: 'phone-1',
        platform: 'ANDROID',
        pushToken: 'native-token',
      );

      expect(adapter.request.method, 'POST');
      expect(adapter.request.path, '/api/v1/me/devices');
      expect(adapter.request.data, {
        'deviceId': 'phone-1',
        'platform': 'ANDROID',
        'pushToken': 'native-token',
      });
    },
  );

  test(
    'push tap resolves the current-recipient read response and stale target',
    () async {
      adapter.response = <String, dynamic>{
        'id': 'notification-1',
        'category': 'ACTIVITY',
        'title': 'Activity ended',
        'body': 'This target is no longer available',
        'group': {'id': 'group-1', 'name': 'Group', 'status': 'ACTIVE'},
        'target': {
          'targetType': 'ACTIVITY',
          'targetId': 'activity-1',
          'route': '/activities/detail',
          'actionable': false,
          'nonActionableReason': 'Activity is cancelled',
          'params': <String, dynamic>{},
        },
        'read': true,
        'readAt': '2026-09-29T12:00:00Z',
        'createdAt': '2026-09-29T11:00:00Z',
      };

      final item = await api.markReadForTap('notification-1');

      expect(adapter.request.method, 'POST');
      expect(adapter.request.path, '/api/v1/notifications/notification-1/read');
      expect(item.notificationId, 'notification-1');
      expect(item.isRead, isTrue);
      expect(item.target.actionable, isFalse);
      expect(item.target.nonActionableReason, 'Activity is cancelled');
    },
  );
}

class _RecordingAdapter implements HttpClientAdapter {
  late RequestOptions request;
  Map<String, dynamic> response = <String, dynamic>{};

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
