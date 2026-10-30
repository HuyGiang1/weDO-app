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
  bool _disposed = false;
  int _loadGeneration = 0, _badgeGeneration = 0, _accessGeneration = 0;
  bool readNeedsRecovery = false;
  void denyAccess() {
    if (_disposed) return;
    _accessGeneration++; _loadGeneration++; _badgeGeneration++;
    readNeedsRecovery = false;
    value = const NotificationCenterState(errorMessage: 'Bạn không có quyền xem thông báo.');
  }
  void _reportUnexpected(NotificationFailure failure) {
    if (failure.cause != null) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: failure.cause!, library: 'NotificationCenterController'));
    }
  }
  NotificationCenterController(this.repository)
    : super(const NotificationCenterState());

  final NotificationRepository repository;

  Future<void> loadInbox({int page = 0, int size = 30, bool silent = false}) async {
    if (_disposed) return;
    final generation = ++_loadGeneration;
    _badgeGeneration++;
    if (!silent) value = value.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
        repository.getInbox(page: page, size: size),
        repository.getUnreadCount(),
      ]);
      final NotificationInboxPageModel inbox = results[0] as NotificationInboxPageModel;
      final int unreadCount = results[1] as int;
      if (_disposed || generation != _loadGeneration) return;
      readNeedsRecovery = false;
      value = value.copyWith(
        isLoading: false,
        inbox: inbox,
        unreadCount: unreadCount,
        clearErrorMessage: true,
      );
    } on NotificationFailure catch (failure) {
      if (_disposed || generation != _loadGeneration) return;
      readNeedsRecovery = failure.isTransient;
      _reportUnexpected(failure);
      value = [401,403,404].contains(failure.statusCode)
          ? NotificationCenterState(errorMessage: failure.message)
          : value.copyWith(isLoading: false, errorMessage: failure.message);
    } catch (error, stack) {
      if (_disposed || generation != _loadGeneration) return;
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
      value = value.copyWith(
        isLoading: false,
        errorMessage: 'Không thể tải danh sách thông báo.',
      );
    }
  }

  @override
  void dispose() { _disposed = true; _loadGeneration++; _badgeGeneration++; _accessGeneration++; super.dispose(); }

  Future<void> refreshUnreadCount() async {
    if (_disposed) return;
    final generation = ++_badgeGeneration, load = _loadGeneration;
    try {
      final count = await repository.getUnreadCount();
      if (_disposed || generation != _badgeGeneration || load != _loadGeneration) return;
      value = value.copyWith(unreadCount: count);
    } on NotificationFailure catch (failure) {
      _reportUnexpected(failure);
    }
  }

  Future<void> markRead(String notificationId) async {
    if (_disposed || value.inbox == null) return;
    final access = _accessGeneration;
    _loadGeneration++; _badgeGeneration++;
    try {
      await repository.markRead(notificationId);
      if (_disposed || access != _accessGeneration) return;
      await loadInbox(silent: true);
    } on NotificationFailure catch (failure) {
      if (_disposed || access != _accessGeneration) return;
      _reportUnexpected(failure);
      value = value.copyWith(errorMessage: failure.message);
    }
  }

  Future<int> markAllRead() async {
    if (_disposed) return 0;
    final access = _accessGeneration;
    _loadGeneration++; _badgeGeneration++;
    value = value.copyWith(isMutating: true, clearErrorMessage: true);
    try {
      final updated = await repository.markAllRead();
      if (_disposed || access != _accessGeneration) return updated;
      // Canonical read preserves notifications created after the mark-all commit.
      await loadInbox(silent: true);
      if (!_disposed && access == _accessGeneration) value = value.copyWith(isMutating: false);
      return updated;
    } on NotificationFailure catch (failure) {
      if (!_disposed && access == _accessGeneration) {
        _reportUnexpected(failure);
        value = value.copyWith(isMutating: false, errorMessage: failure.message);
      }
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
