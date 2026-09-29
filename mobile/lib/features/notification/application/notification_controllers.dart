import 'package:flutter/foundation.dart';

import '../data/notification_failure.dart';
import '../data/notification_models.dart';
import '../data/notification_repository.dart';

class NotificationCenterState {
  const NotificationCenterState({
    this.isLoading = false,
    this.isMutating = false,
    this.unreadCount = 0,
    this.inbox,
    this.errorMessage,
  });

  final bool isLoading;
  final bool isMutating;
  final int unreadCount;
  final NotificationInboxPageModel? inbox;
  final String? errorMessage;

  NotificationCenterState copyWith({
    bool? isLoading,
    bool? isMutating,
    int? unreadCount,
    NotificationInboxPageModel? inbox,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return NotificationCenterState(
      isLoading: isLoading ?? this.isLoading,
      isMutating: isMutating ?? this.isMutating,
      unreadCount: unreadCount ?? this.unreadCount,
      inbox: inbox ?? this.inbox,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class NotificationSettingsState {
  const NotificationSettingsState({
    this.isLoading = false,
    this.isSaving = false,
    required this.settings,
    this.errorMessage,
  });

  factory NotificationSettingsState.initial() {
    return NotificationSettingsState(
      isLoading: false,
      isSaving: false,
      settings: UserNotificationSettingsModel.defaults(),
    );
  }

  final bool isLoading;
  final bool isSaving;
  final UserNotificationSettingsModel settings;
  final String? errorMessage;

  NotificationSettingsState copyWith({
    bool? isLoading,
    bool? isSaving,
    UserNotificationSettingsModel? settings,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return NotificationSettingsState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      settings: settings ?? this.settings,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class GroupNotificationSettingsState {
  const GroupNotificationSettingsState({
    this.isLoading = false,
    this.isSaving = false,
    this.settings,
    this.errorMessage,
  });

  final bool isLoading;
  final bool isSaving;
  final GroupNotificationSettingsModel? settings;
  final String? errorMessage;

  GroupNotificationSettingsState copyWith({
    bool? isLoading,
    bool? isSaving,
    GroupNotificationSettingsModel? settings,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return GroupNotificationSettingsState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      settings: settings ?? this.settings,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class NotificationCenterController extends ValueNotifier<NotificationCenterState> {
  NotificationCenterController(this.repository)
    : super(const NotificationCenterState());

  final NotificationRepository repository;

  Future<void> loadInbox({int page = 0, int size = 30}) async {
    value = value.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
        repository.getInbox(page: page, size: size),
        repository.getUnreadCount(),
      ]);
      final NotificationInboxPageModel inbox = results[0] as NotificationInboxPageModel;
      final int unreadCount = results[1] as int;
      value = value.copyWith(
        isLoading: false,
        inbox: inbox,
        unreadCount: unreadCount,
        clearErrorMessage: true,
      );
    } on NotificationFailure catch (failure) {
      value = value.copyWith(isLoading: false, errorMessage: failure.message);
    } catch (_) {
      value = value.copyWith(
        isLoading: false,
        errorMessage: 'Không thể tải danh sách thông báo.',
      );
    }
  }

  Future<void> refreshUnreadCount() async {
    try {
      final int count = await repository.getUnreadCount();
      value = value.copyWith(unreadCount: count);
    } catch (_) {
      // Best-effort badge refresh
    }
  }

  Future<void> markRead(String notificationId) async {
    final NotificationInboxPageModel? currentInbox = value.inbox;
    if (currentInbox == null) {
      return;
    }
    try {
      final MarkNotificationReadResult result = await repository.markRead(notificationId);
      final List<NotificationItemModel> updatedItems = currentInbox.items
          .map(
            (NotificationItemModel item) => item.notificationId == notificationId
                ? item.copyWith(isRead: result.isRead, readAt: result.readAt)
                : item,
          )
          .toList(growable: false);
      final int nextUnread = updatedItems
          .where((NotificationItemModel item) => !item.isRead)
          .length;
      value = value.copyWith(
        inbox: currentInbox.copyWith(items: updatedItems),
        unreadCount: nextUnread,
        clearErrorMessage: true,
      );
      await refreshUnreadCount();
    } on NotificationFailure catch (failure) {
      value = value.copyWith(errorMessage: failure.message);
    } catch (_) {
      value = value.copyWith(errorMessage: 'Không thể đánh dấu thông báo đã đọc.');
    }
  }

  Future<int> markAllRead() async {
    value = value.copyWith(isMutating: true, clearErrorMessage: true);
    try {
      final int updatedCount = await repository.markAllRead();
      final NotificationInboxPageModel? currentInbox = value.inbox;
      final NotificationInboxPageModel? nextInbox = currentInbox?.copyWith(
              items: currentInbox.items
                  .map(
                    (NotificationItemModel item) => item.copyWith(
                      isRead: true,
                      readAt: item.readAt ?? DateTime.now(),
                    ),
                  )
                  .toList(growable: false),
            );
      value = value.copyWith(
        isMutating: false,
        inbox: nextInbox,
        unreadCount: 0,
        clearErrorMessage: true,
      );
      return updatedCount;
    } on NotificationFailure catch (failure) {
      value = value.copyWith(isMutating: false, errorMessage: failure.message);
      rethrow;
    } catch (_) {
      value = value.copyWith(
        isMutating: false,
        errorMessage: 'Không thể đánh dấu tất cả đã đọc.',
      );
      rethrow;
    }
  }

  Future<void> syncDeviceTokenBestEffort({
    required String deviceId,
    required String platform,
    required String pushToken,
  }) async {
    if (deviceId.trim().isEmpty ||
        platform.trim().isEmpty ||
        pushToken.trim().isEmpty) {
      return;
    }
    try {
      await repository.registerDevice(
        deviceId: deviceId,
        platform: platform,
        pushToken: pushToken,
      );
    } catch (_) {
      // A supplied native token must never block notification center usage.
    }
  }

  Future<void> deactivateDeviceBestEffort(String deviceId) async {
    if (deviceId.trim().isEmpty) return;
    try {
      await repository.deactivateDevice(deviceId);
    } catch (_) {
      // Best-effort device cleanup on logout.
    }
  }
}

class NotificationSettingsController extends ValueNotifier<NotificationSettingsState> {
  NotificationSettingsController(this.repository)
    : super(NotificationSettingsState.initial());

  final NotificationRepository repository;

  Future<void> loadSettings() async {
    value = value.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final UserNotificationSettingsModel settings = await repository
          .getUserNotificationSettings();
      value = value.copyWith(
        isLoading: false,
        settings: settings,
        clearErrorMessage: true,
      );
    } on NotificationFailure catch (failure) {
      value = value.copyWith(isLoading: false, errorMessage: failure.message);
    } catch (_) {
      value = value.copyWith(
        isLoading: false,
        errorMessage: 'Không thể tải cài đặt thông báo.',
      );
    }
  }

  Future<void> updateToggle({
    bool? pushEnabled,
    bool? socialEnabled,
    bool? groupEnabled,
    bool? chatEnabled,
    bool? activityEnabled,
    bool? pollEnabled,
    bool? taskEnabled,
    bool? financeEnabled,
    bool? fundEnabled,
  }) async {
    final UserNotificationSettingsModel optimistic = value.settings.copyWith(
      pushEnabled: pushEnabled,
      socialEnabled: socialEnabled,
      groupEnabled: groupEnabled,
      chatEnabled: chatEnabled,
      activityEnabled: activityEnabled,
      pollEnabled: pollEnabled,
      taskEnabled: taskEnabled,
      financeEnabled: financeEnabled,
      fundEnabled: fundEnabled,
    );
    value = value.copyWith(
      isSaving: true,
      settings: optimistic,
      clearErrorMessage: true,
    );
    try {
      final UserNotificationSettingsModel saved = await repository
          .updateUserNotificationSettings(
            pushEnabled: pushEnabled,
            socialEnabled: socialEnabled,
            groupEnabled: groupEnabled,
            chatEnabled: chatEnabled,
            activityEnabled: activityEnabled,
            pollEnabled: pollEnabled,
            taskEnabled: taskEnabled,
            financeEnabled: financeEnabled,
            fundEnabled: fundEnabled,
          );
      value = value.copyWith(
        isSaving: false,
        settings: saved,
        clearErrorMessage: true,
      );
    } on NotificationFailure catch (failure) {
      value = value.copyWith(isSaving: false, errorMessage: failure.message);
    } catch (_) {
      value = value.copyWith(
        isSaving: false,
        errorMessage: 'Không thể lưu cài đặt thông báo.',
      );
    }
  }
}

class GroupNotificationSettingsController
    extends ValueNotifier<GroupNotificationSettingsState> {
  GroupNotificationSettingsController({
    required this.repository,
    required this.groupId,
  }) : super(const GroupNotificationSettingsState());

  final NotificationRepository repository;
  final String groupId;

  Future<void> loadSettings() async {
    value = value.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final GroupNotificationSettingsModel settings = await repository
          .getGroupNotificationSettings(groupId);
      value = value.copyWith(
        isLoading: false,
        settings: settings,
        clearErrorMessage: true,
      );
    } on NotificationFailure catch (failure) {
      value = value.copyWith(isLoading: false, errorMessage: failure.message);
    } catch (_) {
      value = value.copyWith(
        isLoading: false,
        errorMessage: 'Không thể tải cài đặt thông báo nhóm.',
      );
    }
  }

  Future<GroupNotificationSettingsModel> setMute({
    required bool isMuted,
    String? muteDuration,
  }) async {
    value = value.copyWith(isSaving: true, clearErrorMessage: true);
    try {
      final GroupNotificationSettingsModel updated = await repository
          .updateGroupNotificationSettings(
            groupId: groupId,
            isMuted: isMuted,
            muteDuration: muteDuration,
          );
      value = value.copyWith(
        isSaving: false,
        settings: updated,
        clearErrorMessage: true,
      );
      return updated;
    } on NotificationFailure catch (failure) {
      value = value.copyWith(isSaving: false, errorMessage: failure.message);
      rethrow;
    } catch (_) {
      value = value.copyWith(
        isSaving: false,
        errorMessage: 'Không thể cập nhật thông báo nhóm.',
      );
      rethrow;
    }
  }
}
