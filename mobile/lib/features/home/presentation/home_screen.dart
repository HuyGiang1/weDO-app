import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/utils/date_time_formatter.dart';
import '../../groups/presentation/widgets/group_widgets.dart';
import '../../notification/data/notification_models.dart';
import '../application/home_controller.dart';
import '../data/home_models.dart';

class HomeScreen extends StatefulWidget {
  final HomeController controller;
  final ValueChanged<String> onOpenGroup;
  final ValueChanged<String> onOpenActivity;
  final ValueChanged<String> onOpenBalance;
  final ValueChanged<HomeAction> onOpenAction;
  final ValueChanged<NotificationItemModel> onOpenUpdate;
  final VoidCallback onGroups;
  final VoidCallback onChat;
  final VoidCallback onCalendar;
  final VoidCallback onProfile;
  final VoidCallback? onNotifications;

  const HomeScreen({
    super.key,
    required this.controller,
    required this.onOpenGroup,
    required this.onOpenActivity,
    required this.onOpenBalance,
    required this.onOpenAction,
    required this.onOpenUpdate,
    required this.onGroups,
    required this.onChat,
    required this.onCalendar,
    required this.onProfile,
    this.onNotifications,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Trang chủ'),
      backgroundColor: AppColors.background,
      actions: [
        if (widget.onNotifications != null)
          IconButton(
            tooltip: 'Thông báo',
            onPressed: widget.onNotifications,
            icon: const Icon(Icons.notifications_none),
          ),
      ],
    ),
    bottomNavigationBar: GroupsBottomNavigation(
      currentIndex: 0,
      onTap: (index) {
        if (index == 1) widget.onGroups();
        if (index == 2) widget.onChat();
        if (index == 3) widget.onCalendar();
        if (index == 4) widget.onProfile();
      },
    ),
    body: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        final state = widget.controller;
        final value = state.value;
        if (value == null && state.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (value == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Không thể tải trang chủ.'),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: state.load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: state.load,
          child: ListView(
            children: [
              if (state.loading) const LinearProgressIndicator(minHeight: 2),
              if (state.error != null)
                ListTile(
                  title: const Text('Không thể cập nhật trang chủ.'),
                  trailing: IconButton(
                    tooltip: 'Thử lại',
                    onPressed: state.load,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              _section('Nhóm gần đây', Icons.groups_outlined),
              if (value.recentGroups.isEmpty)
                const _EmptyRow('Chưa có nhóm nào.')
              else
                for (final group in value.recentGroups)
                  ListTile(
                    key: Key('home-group-${group.id}'),
                    leading: GroupAvatar(
                      name: group.name,
                      avatarStorageKey: group.avatarStorageKey,
                      radius: 20,
                    ),
                    title: Text(group.name),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => widget.onOpenGroup(group.id),
                  ),
              const Divider(height: 16),
              _section('Hoạt động sắp tới', Icons.event_outlined),
              if (value.upcomingActivities.isEmpty)
                const _EmptyRow('Chưa có hoạt động sắp tới.')
              else
                for (final activity in value.upcomingActivities)
                  ListTile(
                    key: Key('home-activity-${activity.id}'),
                    title: Text(activity.title),
                    subtitle: Text(
                      '${activity.groupName} · ${AppDateTimeFormatter.formatDateTime(activity.startAt)}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => widget.onOpenActivity(activity.id),
                  ),
              const Divider(height: 16),
              _section('Tài chính', Icons.account_balance_wallet_outlined),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _amount(
                        'Bạn cần trả',
                        value.financeSummary.owedByMe.formatted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _amount(
                        'Bạn cần nhận',
                        value.financeSummary.owedToMe.formatted,
                      ),
                    ),
                  ],
                ),
              ),
              if (value.financeSummary.groups.isEmpty)
                const _EmptyRow('Chưa có số dư cần thanh toán.')
              else
                for (final balance in value.financeSummary.groups)
                  ListTile(
                    key: Key('home-balance-${balance.groupId}'),
                    title: Text(balance.groupName),
                    subtitle: Text(
                      'Cần trả ${balance.owedByMe.formatted} · Cần nhận ${balance.owedToMe.formatted}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => widget.onOpenBalance(balance.groupId),
                  ),
              const Divider(height: 16),
              _section('Cần xử lý', Icons.task_alt_outlined),
              if (value.actionsRequired.isEmpty)
                const _EmptyRow('Không có việc cần xử lý.')
              else
                for (final action in value.actionsRequired)
                  ListTile(
                    key: Key('home-action-${action.targetId}'),
                    leading: Icon(
                      _actionIcon(action.type),
                      color: AppColors.primary,
                    ),
                    title: Text(action.title),
                    subtitle: Text(
                      action.dueAt == null
                          ? _actionLabel(action.type)
                          : '${_actionLabel(action.type)} · ${AppDateTimeFormatter.formatDateTime(action.dueAt!)}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => widget.onOpenAction(action),
                  ),
              const Divider(height: 16),
              _section('Cập nhật gần đây', Icons.notifications_none_outlined),
              if (value.recentUpdates.isEmpty)
                const _EmptyRow('Chưa có cập nhật nào.')
              else
                for (final update in value.recentUpdates)
                  ListTile(
                    key: Key('home-update-${update.notificationId}'),
                    leading: Icon(
                      update.isRead
                          ? Icons.notifications_none
                          : Icons.notifications_active_outlined,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      update.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${update.body} · ${AppDateTimeFormatter.formatDateTime(update.createdAt)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => widget.onOpenUpdate(update),
                  ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    ),
  );

  Widget _section(String title, IconData icon) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
    child: Row(
      children: [
        Icon(icon, size: 20, color: AppColors.secondary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  Widget _amount(String label, String amount) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: AppColors.onSurfaceVariant)),
      Text(
        amount,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    ],
  );

  static String _actionLabel(HomeActionType type) => switch (type) {
    HomeActionType.rsvpRequired => 'Phản hồi tham gia',
    HomeActionType.pollVoteRequired => 'Bình chọn',
    HomeActionType.taskDue => 'Công việc đến hạn',
    HomeActionType.settlementConfirmation => 'Xác nhận thanh toán',
  };

  static IconData _actionIcon(HomeActionType type) => switch (type) {
    HomeActionType.rsvpRequired => Icons.event_available_outlined,
    HomeActionType.pollVoteRequired => Icons.how_to_vote_outlined,
    HomeActionType.taskDue => Icons.checklist_outlined,
    HomeActionType.settlementConfirmation => Icons.payments_outlined,
  };
}

class _EmptyRow extends StatelessWidget {
  final String text;
  const _EmptyRow(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    child: Text(
      text,
      style: const TextStyle(color: AppColors.onSurfaceVariant),
    ),
  );
}
