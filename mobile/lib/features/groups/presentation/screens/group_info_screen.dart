import 'package:flutter/material.dart';

import '../../../../core/realtime/realtime_binding.dart';

import '../../../../core/ui/widgets/app_management.dart';
import '../../../../core/l10n/domain_labels.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../application/group_detail_controller.dart';
import '../../data/group_failure.dart';
import '../../data/models/group_models.dart';
import '../widgets/group_widgets.dart';

class GroupInfoScreen extends StatefulWidget {
  final String groupId;
  final GroupDetailController controller;
  final VoidCallback onEdit, onMembers, onSettings, onActivityLog, onLeave;
  final VoidCallback? onActivities;
  final VoidCallback? onMemories;
  final VoidCallback? onExpenses;
  final VoidCallback? onSettlements;
  final VoidCallback? onFund;
  final VoidCallback? onNotificationMute;
  final VoidCallback? onChat;
  final VoidCallback? onChatHome;
  final VoidCallback? onCalendar;
  final VoidCallback? onHome;
  final VoidCallback? onGroups;
  final VoidCallback? onProfile;
  final VoidCallback? onInviteLinks, onJoinRequests, onBans;
  final VoidCallback? onArchive, onRestore, onDelete, onTransferOwnership;

  const GroupInfoScreen({
    super.key,
    required this.groupId,
    required this.controller,
    required this.onEdit,
    required this.onMembers,
    required this.onSettings,
    required this.onActivityLog,
    required this.onLeave,
    this.onActivities,
    this.onMemories,
    this.onExpenses,
    this.onSettlements,
    this.onFund,
    this.onNotificationMute,
    this.onChat,
    this.onChatHome,
    this.onCalendar,
    this.onHome,
    this.onGroups,
    this.onProfile,
    this.onInviteLinks,
    this.onJoinRequests,
    this.onBans,
    this.onArchive,
    this.onRestore,
    this.onDelete,
    this.onTransferOwnership,
  });

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen>
    with RealtimeBinding<GroupInfoScreen> {
  @override
  String? get realtimeScope => 'group:${widget.groupId}';
  @override
  String get realtimePrefix => 'GROUP_';
  @override
  Future<void> reloadRealtime() => widget.controller.resync(widget.groupId);
  @override
  void initState() {
    super.initState();
    widget.controller.load(widget.groupId);
  }

  Future<void> confirm(
    String title,
    String message,
    VoidCallback action,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) action();
  }

  Widget section(List<Widget> rows) => AppSurface(
    child: Column(
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(indent: 64),
          rows[i],
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Thông tin nhóm')),
    bottomNavigationBar: GroupsBottomNavigation(
      onTap: (index) {
        if (index == 0) widget.onHome?.call();
        if (index == 1) widget.onGroups?.call();
        if (index == 2) widget.onChatHome?.call();
        if (index == 3) widget.onCalendar?.call();
        if (index == 4) widget.onProfile?.call();
      },
    ),
    body: ValueListenableBuilder<GroupDetailState>(
      valueListenable: widget.controller,
      builder: (context, state, _) {
        if (state.loading && state.detail == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final group = state.detail;
        if (group == null) {
          return Center(
            child: OutlinedButton.icon(
              onPressed: () => widget.controller.load(widget.groupId),
              icon: const Icon(Icons.refresh),
              label: const Text(AppStrings.retry),
            ),
          );
        }
        final owner = group.callerRole == GroupRole.owner;
        final manager = owner || group.callerRole == GroupRole.admin;
        final active = group.status == GroupStatus.active;
        final canEdit =
            active &&
            (manager || state.settings?.memberModifyInfoAllowed == true);
        final colors = Theme.of(context).colorScheme;
        return RefreshIndicator(
          onRefresh: reloadRealtime,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              AppSurface(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GroupAvatar(
                          name: group.name,
                          avatarStorageKey: group.avatarStorageKey,
                          radius: 32,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.name,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  GroupRoleBadge(role: group.callerRole),
                                  AppStatusLabel(
                                    group.status.label,
                                    tone: active
                                        ? AppTone.neutral
                                        : AppTone.warning,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (group.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 14),
                      Text(
                        group.description!,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Nội dung dành cho thành viên',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    if (canEdit) ...[
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: widget.onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Sửa thông tin nhóm'),
                      ),
                    ],
                  ],
                ),
              ),
              if (!active)
                const AppNotice(
                  AppStrings.groupArchivedBanner,
                  tone: AppTone.warning,
                ),
              if (state.failure?.type == GroupFailureType.transferRequired)
                const AppNotice(
                  'Vui lòng chuyển quyền trưởng nhóm trước khi rời nhóm.',
                  tone: AppTone.warning,
                ),
              const AppSectionHeader('Thành viên'),
              AppSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chủ nhóm',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            state.owner == null
                                ? 'Tên chủ nhóm chưa khả dụng'
                                : (state.owner!.displayName.trim().isNotEmpty
                                      ? state.owner!.displayName
                                      : '@${state.owner!.username}'),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    if (state.members.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final member in state.members.take(4))
                              Tooltip(
                                message: member.displayName,
                                child: GroupAvatar(
                                  name: member.displayName,
                                  avatarStorageKey: member.avatarStorageKey,
                                  radius: 18,
                                ),
                              ),
                          ],
                        ),
                      ),
                    AppManagementRow(
                      icon: Icons.people_outline,
                      title: 'Thành viên nhóm',
                      status: state.memberCount?.toString(),
                      subtitle: 'Xem danh sách và vai trò',
                      onTap: widget.onMembers,
                    ),
                  ],
                ),
              ),
              const AppSectionHeader('Cùng nhau thực hiện'),
              section([
                if (widget.onActivities != null)
                  AppManagementRow(
                    icon: Icons.event_outlined,
                    title: 'Hoạt động',
                    subtitle: 'Lịch trình, công việc và bình chọn',
                    onTap: widget.onActivities,
                  ),
                if (widget.onChat != null)
                  AppManagementRow(
                    icon: Icons.chat_bubble_outline,
                    title: 'Trò chuyện',
                    onTap: widget.onChat,
                  ),
                if (widget.onMemories != null)
                  AppManagementRow(
                    icon: Icons.photo_library_outlined,
                    title: 'Khoảnh khắc & Album',
                    onTap: widget.onMemories,
                  ),
                if (widget.onExpenses != null)
                  AppManagementRow(
                    icon: Icons.receipt_long_outlined,
                    title: 'Chi tiêu',
                    onTap: widget.onExpenses,
                  ),
                if (widget.onSettlements != null)
                  AppManagementRow(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Thanh toán công nợ',
                    onTap: widget.onSettlements,
                  ),
                if (widget.onFund != null)
                  AppManagementRow(
                    icon: Icons.savings_outlined,
                    title: 'Quỹ nhóm',
                    onTap: widget.onFund,
                  ),
              ]),
              const AppSectionHeader('Truy cập & quản lý'),
              section([
                if (manager && widget.onInviteLinks != null)
                  AppManagementRow(
                    icon: Icons.qr_code_rounded,
                    title: 'Mã QR & liên kết mời',
                    subtitle: 'Chia sẻ và quản lý lời mời',
                    onTap: widget.onInviteLinks,
                  ),
                if (manager && widget.onJoinRequests != null)
                  AppManagementRow(
                    icon: Icons.person_add_outlined,
                    title: 'Yêu cầu tham gia',
                    status: state.pendingJoinRequestCount?.toString(),
                    subtitle: 'Xem và duyệt yêu cầu đang chờ',
                    onTap: widget.onJoinRequests,
                  ),
                if (manager && widget.onBans != null)
                  AppManagementRow(
                    icon: Icons.block,
                    title: 'Danh sách chặn',
                    onTap: widget.onBans,
                  ),
                AppManagementRow(
                  icon: Icons.tune,
                  title: 'Cài đặt nhóm',
                  subtitle: 'Quyền và cách tham gia',
                  onTap: widget.onSettings,
                ),
                if (manager)
                  AppManagementRow(
                    icon: Icons.manage_accounts_outlined,
                    title: 'Quản lý thành viên',
                    onTap: widget.onMembers,
                  ),
                if (owner && active && widget.onTransferOwnership != null)
                  AppManagementRow(
                    icon: Icons.swap_horiz,
                    title: 'Chuyển quyền trưởng nhóm',
                    onTap: widget.onTransferOwnership,
                  ),
                if (widget.onNotificationMute != null)
                  AppManagementRow(
                    icon: Icons.notifications_off_outlined,
                    title: 'Tắt thông báo nhóm',
                    onTap: widget.onNotificationMute,
                  ),
                AppManagementRow(
                  icon: Icons.history,
                  title: 'Nhật ký nhóm',
                  onTap: widget.onActivityLog,
                ),
              ]),
              const AppSectionHeader('Hành động khác'),
              section([
                if (owner && active && widget.onArchive != null)
                  AppManagementRow(
                    icon: Icons.archive_outlined,
                    title: AppStrings.archiveGroup,
                    tone: AppTone.warning,
                    onTap: () => confirm(
                      AppStrings.archiveGroupConfirmTitle,
                      AppStrings.archiveGroupConfirmMessage,
                      widget.onArchive!,
                    ),
                  ),
                if (owner &&
                    group.status == GroupStatus.archived &&
                    widget.onRestore != null)
                  AppManagementRow(
                    icon: Icons.unarchive_outlined,
                    title: AppStrings.restoreGroup,
                    tone: AppTone.success,
                    onTap: () => confirm(
                      AppStrings.restoreGroupConfirmTitle,
                      AppStrings.restoreGroupConfirmMessage,
                      widget.onRestore!,
                    ),
                  ),
                AppManagementRow(
                  icon: Icons.logout,
                  title: 'Rời nhóm',
                  tone: AppTone.danger,
                  onTap: () => confirm(
                    'Rời nhóm?',
                    'Bạn sẽ mất quyền truy cập nội dung của nhóm.',
                    () async {
                      final left = await widget.controller.leave(
                        widget.groupId,
                      );
                      if (!context.mounted) return;
                      if (left) {
                        widget.onLeave();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              widget.controller.value.failure?.type ==
                                      GroupFailureType.transferRequired
                                  ? 'Vui lòng chuyển quyền trưởng nhóm trước khi rời nhóm.'
                                  : 'Không thể rời nhóm. Vui lòng thử lại.',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
                if (owner && widget.onDelete != null)
                  AppManagementRow(
                    icon: Icons.delete_forever_outlined,
                    title: 'Xóa nhóm',
                    tone: AppTone.danger,
                    onTap: widget.onDelete,
                  ),
              ]),
            ],
          ),
        );
      },
    ),
  );
}
