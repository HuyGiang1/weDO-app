import 'package:flutter/material.dart';

import '../../../core/ui/widgets/wedo_brand_mark.dart';

import '../../../core/realtime/realtime_binding.dart';
import '../../../core/realtime/reliable_read.dart';

import '../../../app/theme/app_theme.dart';
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
  final VoidCallback? onCommunity;

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
    this.onCommunity,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with RealtimeBinding<HomeScreen> {
  @override
  String get realtimeScope => 'user:self';
  @override
  String get realtimePrefix => 'HOME_';
  @override
  Set<String> get realtimeAdditionalPrefixes => const {
    'NOTIFICATION_',
    'GROUP_',
  };
  @override
  Future<void> reloadRealtime() async {
    final types = takeRealtimeEventTypes();
    if (types.any((type) => type == 'HOME_ACCESS_CHANGED' ||
        (type.startsWith('GROUP_') && type != 'GROUP_UPDATED' && type != 'GROUP_LIST_CHANGED'))) {
      widget.controller.invalidateAccess();
    }
    await widget.controller.load(silent: true);
  }
  @override
  void onRealtimeAccessLost() => widget.controller.invalidateAccess();
  @override
  bool get realtimeReadNeedsRecovery => widget.controller.error != null &&
      ReadFailure.fromError(widget.controller.error!)?.retainData == true;
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
    appBar: AppBar(
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [WeDoBrandMark(size: 32), SizedBox(width: 10), Text('weDO')],
      ),
      actions: [
        if (widget.onNotifications != null)
          IconButton(
            tooltip: 'Thông báo',
            onPressed: widget.onNotifications,
            icon: const Icon(Icons.notifications_outlined),
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
            key: const PageStorageKey('home-content'),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              if (state.loading) const LinearProgressIndicator(minHeight: 2),
              if (state.error != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Không thể cập nhật trang chủ.'),
                  trailing: IconButton(
                    tooltip: 'Thử lại',
                    onPressed: state.load,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              _yourGroups(value.recentGroups),
              _section('Tài chính'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppUi.cardRadius),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Wrap(
                  spacing: 32,
                  runSpacing: 16,
                  children: [
                    _amount(
                      'Bạn cần trả',
                      value.financeSummary.owedByMe.formatted,
                    ),
                    _amount(
                      'Bạn cần nhận',
                      value.financeSummary.owedToMe.formatted,
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
                    contentPadding: EdgeInsets.zero,
                    title: Text(balance.groupName),
                    subtitle: Text(
                      'Cần trả ${balance.owedByMe.formatted} · Cần nhận ${balance.owedToMe.formatted}',
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => widget.onOpenBalance(balance.groupId),
                  ),
              _collapsibleSection(
                'actions',
                'Cần xử lý',
                value.actionsRequired.length,
                [
                  if (value.actionsRequired.isEmpty)
                    const _EmptyRow('Không có việc cần xử lý.')
                  else
                    for (final action in value.actionsRequired)
                      ListTile(
                        key: Key('home-action-${action.targetId}'),
                        contentPadding: EdgeInsets.zero,
                        leading: _icon(_actionIcon(action.type)),
                        title: Text(action.title),
                        subtitle: Text(
                          action.dueAt == null
                              ? _actionLabel(action.type)
                              : '${_actionLabel(action.type)} · ${AppDateTimeFormatter.formatDateTime(action.dueAt!)}',
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => widget.onOpenAction(action),
                      ),
                ],
              ),
              _collapsibleSection(
                'upcoming',
                'Hoạt động sắp tới',
                value.upcomingActivities.length,
                [
                  if (value.upcomingActivities.isEmpty)
                    const _EmptyRow('Chưa có hoạt động sắp tới.')
                  else
                    for (final activity in value.upcomingActivities)
                      ListTile(
                        key: Key('home-activity-${activity.id}'),
                        contentPadding: EdgeInsets.zero,
                        leading: _icon(Icons.event_outlined),
                        title: Text(activity.title),
                        subtitle: Text(
                          '${activity.groupName} · ${AppDateTimeFormatter.formatDateTime(activity.startAt)}',
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => widget.onOpenActivity(activity.id),
                      ),
                ],
              ),
              _collapsibleSection(
                'updates',
                'Cập nhật gần đây',
                value.recentUpdates.length,
                [
                  if (value.recentUpdates.isEmpty)
                    const _EmptyRow('Chưa có cập nhật nào.')
                  else
                    for (final update in value.recentUpdates)
                      ListTile(
                        key: Key('home-update-${update.notificationId}'),
                        contentPadding: EdgeInsets.zero,
                        leading: _icon(
                          update.isRead
                              ? Icons.notifications_none
                              : Icons.notifications_active_outlined,
                        ),
                        title: Text(
                          update.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${update.body} · ${AppDateTimeFormatter.formatDateTime(update.createdAt)}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => widget.onOpenUpdate(update),
                      ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _collapsibleSection(
    String id,
    String title,
    int count,
    List<Widget> children,
  ) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: ExpansionTile(
      key: PageStorageKey('home-section-$id'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      shape: const Border(),
      collapsedShape: const Border(),
      maintainState: true,
      expansionAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      title: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(width: 12),
          Text(
            '$count',
            semanticsLabel: '$count mục trong phần này',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      children: children,
    ),
  );

  Widget _yourGroups(List<HomeGroup> groups) {
    final colors = Theme.of(context).colorScheme;
    final foreground = colors.onInverseSurface;
    return Container(
      key: const ValueKey('home-your-groups'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.inverseSurface,
        borderRadius: BorderRadius.circular(AppUi.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Nhóm của bạn',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: foreground),
                ),
              ),
              TextButton(
                key: const ValueKey('home-all-groups'),
                style: TextButton.styleFrom(foregroundColor: foreground),
                onPressed: widget.onGroups,
                child: const Text('Xem tất cả'),
              ),
            ],
          ),
          if (groups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Bạn chưa có nhóm nào. Cùng bắt đầu một kết nối mới.',
                style: TextStyle(color: foreground.withValues(alpha: .8)),
              ),
            )
          else if (groups.length == 1)
            InkWell(
              key: Key('home-group-${groups.single.id}'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => widget.onOpenGroup(groups.single.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    GroupAvatar(
                      name: groups.single.name,
                      avatarStorageKey: groups.single.avatarStorageKey,
                      radius: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        groups.single.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: foreground, size: 18),
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              key: const PageStorageKey('home-group-previews'),
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final group in groups)
                    SizedBox(
                      width: 128,
                      child: InkWell(
                        key: Key('home-group-${group.id}'),
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => widget.onOpenGroup(group.id),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(0, 8, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GroupAvatar(
                                name: group.name,
                                avatarStorageKey: group.avatarStorageKey,
                                radius: 20,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                group.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: foreground,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: foreground),
            onPressed: widget.onGroups,
            icon: const Icon(Icons.group_add_outlined, size: 18),
            label: const Text('Tạo hoặc tham gia nhóm'),
          ),
        ],
      ),
    );
  }

  Widget _icon(IconData icon) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(icon, size: 20),
  );

  Widget _section(String title, {Widget? action}) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        ?action,
      ],
    ),
  );

  Widget _amount(String label, String amount) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 4),
      Text(amount, style: Theme.of(context).textTheme.titleLarge),
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
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      text,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}
