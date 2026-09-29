import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../activity/data/activity_api.dart';
import '../../activity/data/activity_repository.dart';
import '../../chat/data/chat_api.dart';
import '../../chat/data/chat_repository.dart';
import '../../expense/data/expense_api.dart';
import '../../expense/data/expense_repository.dart';
import '../../expense/presentation/expense_screens.dart';
import '../../fund/data/fund_api.dart';
import '../../fund/data/fund_repository.dart';
import '../../groups/data/group_repository.dart';
import '../application/notification_controllers.dart';
import '../data/notification_models.dart';
import '../data/notification_repository.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({
    super.key,
    required this.repository,
    this.groupRepository,
    this.controller,
  });

  final NotificationRepository repository;
  final GroupRepository? groupRepository;
  final NotificationCenterController? controller;

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  late final NotificationCenterController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ?? NotificationCenterController(widget.repository);
    _controller.loadInbox();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  String _categoryLabel(String category) {
    switch (category.toUpperCase()) {
      case 'SOCIAL':
        return 'Bạn bè';
      case 'GROUP':
        return 'Nhóm';
      case 'CHAT':
        return 'Trò chuyện';
      case 'ACTIVITY':
        return 'Hoạt động';
      case 'POLL':
        return 'Bình chọn';
      case 'TASK':
        return 'Công việc';
      case 'FINANCE':
        return 'Chi tiêu';
      case 'FUND':
        return 'Quỹ nhóm';
      default:
        return 'Hệ thống';
    }
  }

  IconData _categoryIcon(String category) {
    switch (category.toUpperCase()) {
      case 'SOCIAL':
        return Icons.people_outline_rounded;
      case 'GROUP':
        return Icons.groups_outlined;
      case 'CHAT':
        return Icons.chat_bubble_outline_rounded;
      case 'ACTIVITY':
        return Icons.event_outlined;
      case 'POLL':
        return Icons.poll_outlined;
      case 'TASK':
        return Icons.checklist_rounded;
      case 'FINANCE':
        return Icons.receipt_long_outlined;
      case 'FUND':
        return Icons.savings_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _categoryColor(String category) {
    switch (category.toUpperCase()) {
      case 'CHAT':
        return const Color(0xFF0057FF);
      case 'ACTIVITY':
        return const Color(0xFF7B3FF2);
      case 'FINANCE':
        return const Color(0xFFD97706);
      case 'FUND':
        return const Color(0xFF0A8F6A);
      default:
        return const Color(0xFF0057FF);
    }
  }

  String _formatTimestamp(DateTime dateTime) {
    final DateTime local = dateTime.toLocal();
    final String hh = local.hour.toString().padLeft(2, '0');
    final String mm = local.minute.toString().padLeft(2, '0');
    final String dd = local.day.toString().padLeft(2, '0');
    final String mo = local.month.toString().padLeft(2, '0');
    return '$hh:$mm • $dd/$mo/${local.year}';
  }

  Future<void> _handleNotificationTap(NotificationItemModel item) async {
    if (!item.isRead) {
      await _controller.markRead(item.notificationId);
    }
    if (!mounted) {
      return;
    }
    final NotificationTargetModel target = item.target;
    if (!target.actionable) {
      final String reason =
          target.nonActionableReason ??
          'Mục liên kết này không còn khả dụng hoặc đã bị xóa.';
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Không thể mở liên kết'),
            content: Text(reason),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Đã hiểu'),
              ),
            ],
          );
        },
      );
      return;
    }

    final GroupRepository? groupRepo = widget.groupRepository;
    final String? groupId = item.group?.groupId;
    final String groupName = item.group?.groupName ?? 'Nhóm WeDo';
    final String route = target.route.trim();

    if (groupRepo == null) {
      return;
    }
    if (target.targetType.toUpperCase() == 'CONVERSATION' &&
        (groupId == null || groupId.isEmpty)) {
      await Navigator.of(context).pushNamed(
        AppRoutes.chatHome,
        arguments: ChatHomeRouteArgs(
          ChatRepository(ChatApi(groupRepo.api.dio)),
          groupRepo,
        ),
      );
      return;
    }
    if (groupId == null) return;

    if (route == AppRoutes.groupFund) {
      await Navigator.of(context).pushNamed(
        AppRoutes.groupFund,
        arguments: FundRouteArgs(
          repository: FundRepository(FundApi(groupRepo.api.dio)),
          groupRepository: groupRepo,
          groupId: groupId,
          groupName: groupName,
        ),
      );
      return;
    }
    if (route == AppRoutes.groupExpenses) {
      await Navigator.of(context).pushNamed(
        AppRoutes.groupExpenses,
        arguments: ExpenseRouteArgs(
          repository: ExpenseRepository(ExpenseApi(groupRepo.api.dio)),
          groupRepository: groupRepo,
          groupId: groupId,
        ),
      );
      return;
    }
    if (target.targetType.toUpperCase() == 'EXPENSE' &&
        target.targetId != null &&
        target.targetId!.isNotEmpty) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ExpenseDetailScreen(
            groupId: groupId,
            expenseId: target.targetId!,
            repository: ExpenseRepository(ExpenseApi(groupRepo.api.dio)),
            groupRepository: groupRepo,
          ),
        ),
      );
      return;
    }
    if (target.targetType.toUpperCase() == 'SETTLEMENT' &&
        target.targetId != null &&
        target.targetId!.isNotEmpty) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => SettlementDetailScreen(
            groupId: groupId,
            settlementId: target.targetId!,
            repository: ExpenseRepository(ExpenseApi(groupRepo.api.dio)),
          ),
        ),
      );
      return;
    }
    if (route == AppRoutes.groupInvitations) {
      await Navigator.of(context).pushNamed(
        AppRoutes.groupInvitations,
        arguments: GroupsRouteArgs(repository: groupRepo),
      );
      return;
    }
    if (target.targetType.toUpperCase() == 'CONVERSATION') {
      final ChatRepository chatRepository = ChatRepository(
        ChatApi(groupRepo.api.dio),
      );
      await Navigator.of(context).pushNamed(
        AppRoutes.groupChat,
        arguments: ChatRouteArgs(
          repository: chatRepository,
          groupId: groupId,
          groupRepository: groupRepo,
        ),
      );
      return;
    }
    if (route == AppRoutes.activities || route == AppRoutes.activityDetail) {
      final ActivityRepository activityRepo = ActivityRepository(
        api: ActivityApi(groupRepo.api.dio),
      );
      final String? activityId = target.targetType.toUpperCase() == 'ACTIVITY'
          ? target.targetId
          : target.params['activityId']?.toString();
      if (activityId != null && activityId.isNotEmpty) {
        await Navigator.of(context).pushNamed(
          AppRoutes.activityDetail,
          arguments: ActivityDetailRouteArgs(
            repository: activityRepo,
            activityId: activityId,
          ),
        );
      } else {
        await Navigator.of(context).pushNamed(
          AppRoutes.activities,
          arguments: ActivitiesRouteArgs(
            repository: activityRepo,
            groupId: groupId,
          ),
        );
      }
      return;
    }
    await Navigator.of(context).pushNamed(
      AppRoutes.groupInfo,
      arguments: GroupInfoRouteArgs(repository: groupRepo, groupId: groupId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NotificationCenterState>(
      valueListenable: _controller,
      builder: (BuildContext context, NotificationCenterState state, _) {
        final List<NotificationItemModel> items =
            state.inbox?.items ?? const <NotificationItemModel>[];

        return Scaffold(
          backgroundColor: const Color(0xFFF6F9FF),
          appBar: AppBar(
            title: Row(
              children: <Widget>[
                const Text('Thông báo'),
                if (state.unreadCount > 0) ...<Widget>[
                  const SizedBox(width: 8),
                  Container(
                    key: const Key('notification_unread_badge'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0057FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${state.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: <Widget>[
              IconButton(
                key: const Key('open_notification_settings_button'),
                tooltip: 'Cài đặt thông báo',
                onPressed: () {
                  Navigator.of(context).pushNamed(
                    AppRoutes.notificationSettings,
                    arguments: NotificationRouteArgs(
                      repository: widget.repository,
                      groupRepository: widget.groupRepository,
                    ),
                  );
                },
                icon: const Icon(Icons.tune_rounded),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => _controller.loadInbox(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFD7E3F7)),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              state.unreadCount > 0
                                  ? 'Bạn có ${state.unreadCount} thông báo chưa đọc'
                                  : 'Tất cả thông báo đã được đọc',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: Color(0xFF0D1F3C),
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Hộp thư lưu mọi sự kiện nhóm, lịch hẹn, chi tiêu và quỹ nhóm.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF51637D),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        key: const Key('mark_all_notifications_read_button'),
                        onPressed: state.unreadCount == 0 || state.isMutating
                            ? null
                            : () async {
                                try {
                                  final int updated = await _controller
                                      .markAllRead();
                                  if (!context.mounted) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Đã đánh dấu $updated thông báo là đã đọc.',
                                      ),
                                    ),
                                  );
                                } catch (_) {}
                              },
                        icon: const Icon(Icons.done_all_rounded, size: 18),
                        label: const Text('Đánh dấu tất cả đã đọc'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFECDD3)),
                      ),
                      child: Text(
                        state.errorMessage!,
                        style: const TextStyle(color: Color(0xFFBE123C)),
                      ),
                    ),
                  ),
                if (state.isLoading && items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (items.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFD7E3F7)),
                    ),
                    child: const Column(
                      children: <Widget>[
                        Icon(
                          Icons.notifications_paused_outlined,
                          size: 44,
                          color: Color(0xFF64748B),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Chưa có thông báo nào',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Color(0xFF0D1F3C),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Khi có hoạt động mới trong nhóm, quỹ nhóm hoặc trò chuyện, thông báo sẽ hiển thị tại đây.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF51637D)),
                        ),
                      ],
                    ),
                  )
                else
                  ...items.map((NotificationItemModel item) {
                    final Color accent = _categoryColor(item.category);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: item.isRead
                            ? Colors.white
                            : const Color(0xFFEEF5FF),
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          key: Key('notification_item_${item.notificationId}'),
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _handleNotificationTap(item),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: item.isRead
                                    ? const Color(0xFFDCE6F7)
                                    : const Color(0xFF8AB4FF),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _categoryIcon(item.category),
                                    color: accent,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: accent.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              _categoryLabel(item.category),
                                              style: TextStyle(
                                                color: accent,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          if (item.critical) ...<Widget>[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFE4E6),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'Quan trọng',
                                                style: TextStyle(
                                                  color: Color(0xFFBE123C),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ],
                                          const Spacer(),
                                          if (!item.isRead)
                                            Container(
                                              width: 9,
                                              height: 9,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF0057FF),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        item.title,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: item.isRead
                                              ? FontWeight.w700
                                              : FontWeight.w900,
                                          color: const Color(0xFF0D1F3C),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.body,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                      if (!item.target.actionable &&
                                          item.target.nonActionableReason !=
                                              null) ...<Widget>[
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFF7ED),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            item.target.nonActionableReason!,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFFB45309),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 6),
                                      Text(
                                        _formatTimestamp(item.createdAt),
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({
    super.key,
    required this.repository,
    this.controller,
  });

  final NotificationRepository repository;
  final NotificationSettingsController? controller;

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  late final NotificationSettingsController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ?? NotificationSettingsController(widget.repository);
    _controller.loadSettings();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NotificationSettingsState>(
      valueListenable: _controller,
      builder: (BuildContext context, NotificationSettingsState state, _) {
        final UserNotificationSettingsModel settings = state.settings;
        return Scaffold(
          backgroundColor: const Color(0xFFF6F9FF),
          appBar: AppBar(title: const Text('Cài đặt thông báo')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Text(
                  'Lưu ý: Mọi thông báo vẫn luôn được lưu trong hộp thư ứng dụng. Các tùy chọn bên dưới dùng để bật hoặc tắt thông báo đẩy (Push) trên thiết bị.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF1E3A8A)),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: <Widget>[
                    SwitchListTile(
                      key: const Key('toggle_push_enabled'),
                      title: const Text(
                        'Thông báo đẩy (Push)',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: const Text(
                        'Nhận cảnh báo đẩy trên điện thoại khi có sự kiện mới',
                      ),
                      value: settings.pushEnabled,
                      onChanged: (bool value) =>
                          _controller.updateToggle(pushEnabled: value),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      key: const Key('toggle_social_enabled'),
                      title: const Text('Bạn bè & kết nối'),
                      value: settings.socialEnabled,
                      onChanged: (bool value) =>
                          _controller.updateToggle(socialEnabled: value),
                    ),
                    SwitchListTile(
                      key: const Key('toggle_group_enabled'),
                      title: const Text('Nhóm & thành viên'),
                      value: settings.groupEnabled,
                      onChanged: (bool value) =>
                          _controller.updateToggle(groupEnabled: value),
                    ),
                    SwitchListTile(
                      key: const Key('toggle_chat_enabled'),
                      title: const Text('Trò chuyện'),
                      value: settings.chatEnabled,
                      onChanged: (bool value) =>
                          _controller.updateToggle(chatEnabled: value),
                    ),
                    SwitchListTile(
                      key: const Key('toggle_activity_enabled'),
                      title: const Text('Hoạt động & lịch hẹn'),
                      value: settings.activityEnabled,
                      onChanged: (bool value) =>
                          _controller.updateToggle(activityEnabled: value),
                    ),
                    SwitchListTile(
                      key: const Key('toggle_poll_enabled'),
                      title: const Text('Bình chọn'),
                      value: settings.pollEnabled,
                      onChanged: (bool value) =>
                          _controller.updateToggle(pollEnabled: value),
                    ),
                    SwitchListTile(
                      key: const Key('toggle_task_enabled'),
                      title: const Text('Công việc'),
                      value: settings.taskEnabled,
                      onChanged: (bool value) =>
                          _controller.updateToggle(taskEnabled: value),
                    ),
                    SwitchListTile(
                      key: const Key('toggle_finance_enabled'),
                      title: const Text('Chi tiêu & công nợ'),
                      value: settings.financeEnabled,
                      onChanged: (bool value) =>
                          _controller.updateToggle(financeEnabled: value),
                    ),
                    SwitchListTile(
                      key: const Key('toggle_fund_enabled'),
                      title: const Text('Quỹ nhóm'),
                      value: settings.fundEnabled,
                      onChanged: (bool value) =>
                          _controller.updateToggle(fundEnabled: value),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class GroupNotificationSettingsSheet extends StatefulWidget {
  const GroupNotificationSettingsSheet({
    super.key,
    required this.repository,
    required this.groupId,
    required this.groupName,
    this.controller,
  });

  final NotificationRepository repository;
  final String groupId;
  final String groupName;
  final GroupNotificationSettingsController? controller;

  @override
  State<GroupNotificationSettingsSheet> createState() =>
      _GroupNotificationSettingsSheetState();
}

class _GroupNotificationSettingsSheetState
    extends State<GroupNotificationSettingsSheet> {
  late final GroupNotificationSettingsController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        GroupNotificationSettingsController(
          repository: widget.repository,
          groupId: widget.groupId,
        );
    _controller.loadSettings();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _applyMute({
    required bool isMuted,
    String? muteDuration,
    required String feedbackLabel,
  }) async {
    try {
      await _controller.setMute(isMuted: isMuted, muteDuration: muteDuration);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(feedbackLabel)));
      Navigator.of(context).pop();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GroupNotificationSettingsState>(
      valueListenable: _controller,
      builder: (BuildContext context, GroupNotificationSettingsState state, _) {
        final bool isMuted = state.settings?.isMuted ?? false;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.notifications_off_outlined,
                      color: Color(0xFF0057FF),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tắt thông báo nhóm • ${widget.groupName}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0D1F3C),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isMuted
                      ? 'Nhóm này đang tắt thông báo đẩy thông thường. Các sự kiện quan trọng (duyệt quỹ, xác nhận thanh toán, thăng hạng danh sách chờ) vẫn được ưu tiên.'
                      : 'Chọn khoảng thời gian bạn muốn tạm tắt thông báo đẩy từ nhóm này:',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF51637D),
                  ),
                ),
                const SizedBox(height: 14),
                if (isMuted)
                  ListTile(
                    key: const Key('group_mute_option_unmute'),
                    leading: const Icon(
                      Icons.notifications_active_outlined,
                      color: Color(0xFF0A8F6A),
                    ),
                    title: const Text(
                      'Bật lại thông báo nhóm',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    onTap: state.isSaving
                        ? null
                        : () => _applyMute(
                            isMuted: false,
                            feedbackLabel: 'Đã bật lại thông báo cho nhóm.',
                          ),
                  ),
                ListTile(
                  key: const Key('group_mute_option_1h'),
                  leading: const Icon(Icons.schedule_rounded),
                  title: const Text('1 giờ'),
                  onTap: state.isSaving
                      ? null
                      : () => _applyMute(
                          isMuted: true,
                          muteDuration: '1h',
                          feedbackLabel: 'Đã tắt thông báo nhóm trong 1 giờ.',
                        ),
                ),
                ListTile(
                  key: const Key('group_mute_option_8h'),
                  leading: const Icon(Icons.timelapse_rounded),
                  title: const Text('8 giờ'),
                  onTap: state.isSaving
                      ? null
                      : () => _applyMute(
                          isMuted: true,
                          muteDuration: '8h',
                          feedbackLabel: 'Đã tắt thông báo nhóm trong 8 giờ.',
                        ),
                ),
                ListTile(
                  key: const Key('group_mute_option_1d'),
                  leading: const Icon(Icons.today_rounded),
                  title: const Text('1 ngày'),
                  onTap: state.isSaving
                      ? null
                      : () => _applyMute(
                          isMuted: true,
                          muteDuration: '1d',
                          feedbackLabel: 'Đã tắt thông báo nhóm trong 1 ngày.',
                        ),
                ),
                ListTile(
                  key: const Key('group_mute_option_until_unmuted'),
                  leading: const Icon(Icons.do_not_disturb_on_outlined),
                  title: const Text('Cho đến khi bật lại'),
                  onTap: state.isSaving
                      ? null
                      : () => _applyMute(
                          isMuted: true,
                          muteDuration: 'until_unmuted',
                          feedbackLabel:
                              'Đã tắt thông báo nhóm cho đến khi bật lại.',
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
