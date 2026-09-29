import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/notification/data/notification_api.dart';
import 'package:mobile/features/notification/data/notification_models.dart';
import 'package:mobile/features/notification/data/notification_repository.dart';
import 'package:mobile/features/notification/presentation/notification_screens.dart';

class _FakeNotificationRepository extends NotificationRepository {
  _FakeNotificationRepository({required this.inboxItems})
    : super(NotificationApi(Dio()));

  List<NotificationItemModel> inboxItems;
  UserNotificationSettingsModel initialSettings =
      const UserNotificationSettingsModel(
        userId: 'user-1',
        pushEnabled: true,
        socialEnabled: true,
        groupEnabled: true,
        chatEnabled: true,
        activityEnabled: true,
        pollEnabled: true,
        taskEnabled: true,
        financeEnabled: true,
        fundEnabled: true,
      );
  GroupNotificationSettingsModel initialGroupSettings =
      const GroupNotificationSettingsModel(
        groupId: 'group-1',
        userId: 'user-1',
        isMuted: false,
      );
  String? lastMuteDuration;
  bool? lastMuteValue;
  bool registerDeviceCalled = false;

  @override
  Future<NotificationInboxPageModel> getInbox({
    int page = 0,
    int size = 30,
  }) async {
    return NotificationInboxPageModel(
      items: inboxItems,
      page: page,
      size: size,
      totalElements: inboxItems.length,
      totalPages: 1,
      hasNext: false,
    );
  }

  @override
  Future<int> getUnreadCount() async {
    return inboxItems.where((NotificationItemModel i) => !i.isRead).length;
  }

  @override
  Future<MarkNotificationReadResult> markRead(String notificationId) async {
    final DateTime now = DateTime.utc(2026, 9, 28, 16, 0);
    inboxItems = inboxItems
        .map(
          (NotificationItemModel item) => item.notificationId == notificationId
              ? item.copyWith(isRead: true, readAt: now)
              : item,
        )
        .toList(growable: false);
    return MarkNotificationReadResult(
      notificationId: notificationId,
      isRead: true,
      readAt: now,
    );
  }

  @override
  Future<int> markAllRead() async {
    final int unread = inboxItems
        .where((NotificationItemModel i) => !i.isRead)
        .length;
    final DateTime now = DateTime.utc(2026, 9, 28, 16, 5);
    inboxItems = inboxItems
        .map(
          (NotificationItemModel item) =>
              item.copyWith(isRead: true, readAt: item.readAt ?? now),
        )
        .toList(growable: false);
    return unread;
  }

  @override
  Future<UserNotificationSettingsModel> getUserNotificationSettings() async {
    return initialSettings;
  }

  @override
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
  }) async {
    initialSettings = initialSettings.copyWith(
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
    return initialSettings;
  }

  @override
  Future<GroupNotificationSettingsModel> getGroupNotificationSettings(
    String groupId,
  ) async {
    return initialGroupSettings;
  }

  @override
  Future<GroupNotificationSettingsModel> updateGroupNotificationSettings({
    required String groupId,
    required bool isMuted,
    String? muteDuration,
  }) async {
    lastMuteValue = isMuted;
    lastMuteDuration = muteDuration;
    initialGroupSettings = GroupNotificationSettingsModel(
      groupId: groupId,
      userId: 'user-1',
      isMuted: isMuted,
      muteDuration: muteDuration,
    );
    return initialGroupSettings;
  }

  @override
  Future<UserDeviceModel> registerDevice({
    required String deviceId,
    required String platform,
    required String pushToken,
    String? deviceName,
  }) async {
    registerDeviceCalled = true;
    return UserDeviceModel(
      id: 'dev-row-1',
      userId: 'user-1',
      deviceId: deviceId,
      platform: platform,
      pushToken: pushToken,
      active: true,
    );
  }
}

void main() {
  testWidgets(
    'NotificationCenterScreen renders unread badge, marks single & all read, and guards stale target',
    (WidgetTester tester) async {
      final _FakeNotificationRepository repo = _FakeNotificationRepository(
        inboxItems: <NotificationItemModel>[
          NotificationItemModel(
            notificationId: 'notif-1',
            userId: 'user-1',
            category: 'FUND',
            eventType: 'FUND_CONTRIBUTION_CONFIRMED',
            priority: 'HIGH',
            critical: true,
            title: 'Đóng quỹ đã được xác nhận',
            body: 'Khoản đóng 100.000 ₫ đã được xác nhận.',
            isRead: false,
            createdAt: DateTime.utc(2026, 9, 28, 15, 0),
            target: const NotificationTargetModel(
              targetType: 'FUND',
              targetId: 'fund-1',
              route: '/groups/fund',
              actionable: true,
            ),
          ),
          NotificationItemModel(
            notificationId: 'notif-2',
            userId: 'user-1',
            category: 'ACTIVITY',
            eventType: 'ACTIVITY_CREATED',
            priority: 'NORMAL',
            critical: false,
            title: 'Hoạt động đã hủy',
            body: 'Buổi chạy bộ đã bị hủy.',
            isRead: false,
            createdAt: DateTime.utc(2026, 9, 28, 14, 0),
            target: const NotificationTargetModel(
              targetType: 'ACTIVITY',
              targetId: 'act-cancelled',
              route: '/activities/detail',
              actionable: false,
              nonActionableReason:
                  'Hoạt động này đã bị hủy hoặc không còn tồn tại.',
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(home: NotificationCenterScreen(repository: repo)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thông báo'), findsOneWidget);
      expect(repo.registerDeviceCalled, isFalse);
      expect(
        find.byKey(const Key('notification_unread_badge')),
        findsOneWidget,
      );
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Đóng quỹ đã được xác nhận'), findsOneWidget);
      expect(find.text('Quan trọng'), findsOneWidget);

      // Tap stale notification -> marks read and shows non-actionable dialog
      await tester.tap(find.byKey(const Key('notification_item_notif-2')));
      await tester.pumpAndSettle();

      expect(find.text('Không thể mở liên kết'), findsOneWidget);
      expect(
        find.text('Hoạt động này đã bị hủy hoặc không còn tồn tại.'),
        findsWidgets,
      );
      await tester.tap(find.text('Đã hiểu'));
      await tester.pumpAndSettle();

      // Unread count should now be 1
      expect(find.text('1'), findsOneWidget);

      // Mark all read
      await tester.tap(
        find.byKey(const Key('mark_all_notifications_read_button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tất cả thông báo đã được đọc'), findsOneWidget);
      expect(find.byKey(const Key('notification_unread_badge')), findsNothing);
    },
  );

  testWidgets(
    'NotificationSettingsScreen and GroupNotificationSettingsSheet update toggles and mute durations',
    (WidgetTester tester) async {
      final _FakeNotificationRepository repo = _FakeNotificationRepository(
        inboxItems: const <NotificationItemModel>[],
      );

      await tester.pumpWidget(
        MaterialApp(home: NotificationSettingsScreen(repository: repo)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cài đặt thông báo'), findsOneWidget);
      expect(find.text('Thông báo đẩy (Push)'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('toggle_fund_enabled')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('toggle_fund_enabled')));
      await tester.pumpAndSettle();
      expect(repo.initialSettings.fundEnabled, isFalse);

      // Test GroupNotificationSettingsSheet mute options
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupNotificationSettingsSheet(
              repository: repo,
              groupId: 'group-1',
              groupName: 'Nhóm Đà Lạt',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 giờ'), findsOneWidget);
      expect(find.text('8 giờ'), findsOneWidget);
      expect(find.text('1 ngày'), findsOneWidget);
      expect(find.text('Cho đến khi bật lại'), findsOneWidget);

      await tester.tap(find.byKey(const Key('group_mute_option_8h')));
      await tester.pumpAndSettle();

      expect(repo.lastMuteValue, isTrue);
      expect(repo.lastMuteDuration, '8h');
    },
  );
}
