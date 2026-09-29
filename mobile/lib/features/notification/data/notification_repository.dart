import '../../../core/network/api_exception.dart';
import 'notification_api.dart';
import 'notification_failure.dart';
import 'notification_models.dart';

class NotificationRepository {
  const NotificationRepository(this.api);

  final NotificationApi api;

  Future<T> _guard<T>(
    Future<T> Function() action, {
    required String fallbackMessage,
  }) async {
    try {
      return await action();
    } on ApiException catch (error) {
      final String rawMsg = error.message ?? '';
      throw NotificationFailure(
        code: error.code ?? 'API_ERROR',
        message: rawMsg.isNotEmpty ? rawMsg : fallbackMessage,
        statusCode: error.statusCode,
      );
    } on NotificationFailure {
      rethrow;
    } catch (_) {
      throw NotificationFailure(code: 'UNEXPECTED', message: fallbackMessage);
    }
  }

  Future<NotificationInboxPageModel> getInbox({int page = 0, int size = 30}) =>
      _guard(
        () => api.getNotifications(page: page, size: size),
        fallbackMessage: 'Không thể tải danh sách thông báo.',
      );

  Future<int> getUnreadCount() => _guard(
    api.getUnreadCount,
    fallbackMessage: 'Không thể tải số thông báo chưa đọc.',
  );

  Future<MarkNotificationReadResult> markRead(String notificationId) => _guard(
    () => api.markRead(notificationId),
    fallbackMessage: 'Không thể đánh dấu thông báo đã đọc.',
  );

  Future<NotificationItemModel> markReadForTap(String notificationId) => _guard(
    () => api.markReadForTap(notificationId),
    fallbackMessage: 'KhÃ´ng thá»ƒ má»Ÿ thÃ´ng bÃ¡o nÃ y.',
  );

  Future<int> markAllRead() => _guard(
    api.markAllRead,
    fallbackMessage: 'Không thể đánh dấu tất cả đã đọc.',
  );

  Future<UserNotificationSettingsModel> getUserNotificationSettings() => _guard(
    api.getUserNotificationSettings,
    fallbackMessage: 'Không thể tải cài đặt thông báo.',
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
  }) => _guard(
    () => api.updateUserNotificationSettings(
      pushEnabled: pushEnabled,
      socialEnabled: socialEnabled,
      groupEnabled: groupEnabled,
      chatEnabled: chatEnabled,
      activityEnabled: activityEnabled,
      pollEnabled: pollEnabled,
      taskEnabled: taskEnabled,
      financeEnabled: financeEnabled,
      fundEnabled: fundEnabled,
    ),
    fallbackMessage: 'Không thể cập nhật cài đặt thông báo.',
  );

  Future<GroupNotificationSettingsModel> getGroupNotificationSettings(
    String groupId,
  ) => _guard(
    () => api.getGroupNotificationSettings(groupId),
    fallbackMessage: 'Không thể tải cài đặt thông báo nhóm.',
  );

  Future<GroupNotificationSettingsModel> updateGroupNotificationSettings({
    required String groupId,
    required bool isMuted,
    String? muteDuration,
  }) => _guard(
    () => api.updateGroupNotificationSettings(
      groupId: groupId,
      isMuted: isMuted,
      muteDuration: muteDuration,
    ),
    fallbackMessage: 'Không thể cập nhật cài đặt thông báo nhóm.',
  );

  Future<List<UserDeviceModel>> getDevices() => _guard(
    api.getDevices,
    fallbackMessage: 'Không thể tải danh sách thiết bị.',
  );

  Future<UserDeviceModel> registerDevice({
    required String deviceId,
    required String platform,
    required String pushToken,
  }) => _guard(
    () => api.registerDevice(
      deviceId: deviceId,
      platform: platform,
      pushToken: pushToken,
    ),
    fallbackMessage: 'Không thể đăng ký thiết bị nhận thông báo.',
  );

  Future<UserDeviceModel> deactivateDevice(String deviceId) => _guard(
    () => api.deactivateDevice(deviceId),
    fallbackMessage: 'Không thể hủy đăng ký thiết bị.',
  );
}
