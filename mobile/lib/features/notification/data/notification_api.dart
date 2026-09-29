import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import 'notification_models.dart';

class NotificationApi {
  final Dio dio;

  const NotificationApi(this.dio);

  Future<T> _object<T>(
    Future<Response<dynamic>> Function() call,
    T Function(Map<String, dynamic>) parse,
  ) async {
    try {
      final dynamic data = (await call()).data;
      if (data is! Map) {
        throw const FormatException('Expected object response');
      }
      return parse(Map<String, dynamic>.from(data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<T>> _list<T>(
    Future<Response<dynamic>> Function() call,
    T Function(Map<String, dynamic>) parse,
  ) async {
    try {
      final dynamic data = (await call()).data;
      if (data is! List) {
        throw const FormatException('Expected list response');
      }
      return data
          .map((dynamic v) => parse(Map<String, dynamic>.from(v as Map)))
          .toList(growable: false);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<NotificationInboxPageModel> getNotifications({
    int page = 0,
    int size = 30,
  }) => _object(
    () => dio.get(
      '/api/v1/notifications',
      queryParameters: <String, dynamic>{'page': page, 'size': size},
    ),
    NotificationInboxPageModel.fromJson,
  );

  Future<int> getUnreadCount() => _object(
    () => dio.get('/api/v1/notifications/unread-count'),
    (Map<String, dynamic> json) => (json['unreadCount'] as num?)?.toInt() ?? 0,
  );

  Future<MarkNotificationReadResult> markRead(String notificationId) => _object(
    () => dio.post(
      '/api/v1/notifications/${Uri.encodeComponent(notificationId)}/read',
    ),
    MarkNotificationReadResult.fromJson,
  );

  Future<NotificationItemModel> markReadForTap(String notificationId) =>
      _object(
        () => dio.post(
          '/api/v1/notifications/${Uri.encodeComponent(notificationId)}/read',
        ),
        NotificationItemModel.fromJson,
      );

  Future<int> markAllRead() => _object(
    () => dio.post('/api/v1/notifications/read-all'),
    (Map<String, dynamic> json) =>
        ((json['updatedCount'] ?? json['markedCount']) as num?)?.toInt() ?? 0,
  );

  Future<UserNotificationSettingsModel> getUserNotificationSettings() =>
      _object(
        () => dio.get('/api/v1/me/notification-settings'),
        UserNotificationSettingsModel.fromJson,
      );

  Future<UserNotificationSettingsModel> updateUserNotificationSettings({
    bool? pushEnabled,
    bool? socialEnabled,
    bool? groupEnabled,
    bool? chatEnabled,
    bool? activityEnabled,
    bool? pollEnabled,
    bool? taskEnabled,
    bool? financeEnabled,
    bool? fundEnabled,
  }) {
    final Map<String, dynamic> body = <String, dynamic>{
      'pushEnabled': ?pushEnabled,
      'socialEnabled': ?socialEnabled,
      'groupEnabled': ?groupEnabled,
      'chatEnabled': ?chatEnabled,
      'activityEnabled': ?activityEnabled,
      'pollEnabled': ?pollEnabled,
      'taskEnabled': ?taskEnabled,
      'financeEnabled': ?financeEnabled,
      'fundEnabled': ?fundEnabled,
    };
    return _object(
      () => dio.patch('/api/v1/me/notification-settings', data: body),
      UserNotificationSettingsModel.fromJson,
    );
  }

  Future<GroupNotificationSettingsModel> getGroupNotificationSettings(
    String groupId,
  ) => _object(
    () => dio.get(
      '/api/v1/groups/${Uri.encodeComponent(groupId)}/notification-settings',
    ),
    GroupNotificationSettingsModel.fromJson,
  );

  Future<GroupNotificationSettingsModel> updateGroupNotificationSettings({
    required String groupId,
    required bool isMuted,
    String? muteDuration,
  }) => _object(
    () => dio.put(
      '/api/v1/groups/${Uri.encodeComponent(groupId)}/notification-settings',
      data: <String, dynamic>{'muted': isMuted, 'duration': ?muteDuration},
    ),
    GroupNotificationSettingsModel.fromJson,
  );

  Future<List<UserDeviceModel>> getDevices() =>
      _list(() => dio.get('/api/v1/me/devices'), UserDeviceModel.fromJson);

  Future<UserDeviceModel> registerDevice({
    required String deviceId,
    required String platform,
    required String pushToken,
  }) => _object(
    () => dio.post(
      '/api/v1/me/devices',
      data: <String, dynamic>{
        'deviceId': deviceId,
        'platform': platform,
        'pushToken': pushToken,
      },
    ),
    UserDeviceModel.fromJson,
  );

  Future<UserDeviceModel> deactivateDevice(String deviceId) => _object(
    () => dio.delete('/api/v1/me/devices/${Uri.encodeComponent(deviceId)}'),
    UserDeviceModel.fromJson,
  );
}
