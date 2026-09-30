import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
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
  final VoidCallback? onExpenses;
  final VoidCallback? onSettlements;
  final VoidCallback? onFund;
  final VoidCallback? onNotificationMute;
  final VoidCallback? onChat;
  final VoidCallback? onChatHome;
  final VoidCallback? onCalendar;
  final VoidCallback? onInviteLinks, onJoinRequests, onBans;
  final VoidCallback? onArchive, onRestore, onDelete;

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
    this.onExpenses,
    this.onSettlements,
    this.onFund,
    this.onNotificationMute,
    this.onChat,
    this.onChatHome,
    this.onCalendar,
    this.onInviteLinks,
    this.onJoinRequests,
    this.onBans,
    this.onArchive,
    this.onRestore,
    this.onDelete,
  });

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.load(widget.groupId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: true,
        title: const Text(
          'Thông tin nhóm',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
            letterSpacing: -0.3,
          ),
        ),
      ),
      bottomNavigationBar: GroupsBottomNavigation(
        onTap: (index) {
          if (index == 2) widget.onChatHome?.call();
          if (index == 3) widget.onCalendar?.call();
        },
      ),
      body: ValueListenableBuilder<GroupDetailState>(
        valueListenable: widget.controller,
        builder: (context, state, child) {
          if (state.loading) {
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
          return _GroupInfoContent(
            group: group,
            memberCount: state.memberCount,
            onEdit: widget.onEdit,
            onMembers: widget.onMembers,
            onSettings: widget.onSettings,
            onActivityLog: widget.onActivityLog,
            onActivities: widget.onActivities,
            onExpenses: widget.onExpenses,
            onSettlements: widget.onSettlements,
            onFund: widget.onFund,
            onNotificationMute: widget.onNotificationMute,
            onChat: widget.onChat,
            onInviteLinks: widget.onInviteLinks,
            onJoinRequests: widget.onJoinRequests,
            onBans: widget.onBans,
            onArchive: widget.onArchive,
            onRestore: widget.onRestore,
            onDelete: widget.onDelete,
            onLeave: () async {
              if (await widget.controller.leave(widget.groupId) && mounted) {
                widget.onLeave();
              }
            },
            leaveTransferRequired:
                state.failure?.type == GroupFailureType.transferRequired,
          );
        },
      ),
    );
  }
}

class _GroupInfoContent extends StatelessWidget {
  final GroupDetail group;
  final int? memberCount;
  final VoidCallback onEdit, onMembers, onSettings, onActivityLog, onLeave;
  final VoidCallback? onActivities;
  final VoidCallback? onExpenses;
  final VoidCallback? onSettlements;
  final VoidCallback? onFund;
  final VoidCallback? onNotificationMute;
  final VoidCallback? onChat;
  final VoidCallback? onInviteLinks, onJoinRequests, onBans;
  final VoidCallback? onArchive, onRestore, onDelete;
  final bool leaveTransferRequired;

  const _GroupInfoContent({
    required this.group,
    required this.memberCount,
    required this.onEdit,
    required this.onMembers,
    required this.onSettings,
    required this.onActivityLog,
    required this.onLeave,
    this.onActivities,
    this.onExpenses,
    this.onSettlements,
    this.onFund,
    this.onNotificationMute,
    this.onChat,
    this.onInviteLinks,
    this.onJoinRequests,
    this.onBans,
    this.onArchive,
    this.onRestore,
    this.onDelete,
    required this.leaveTransferRequired,
  });

  @override
  Widget build(BuildContext context) {
    final isOwner = group.callerRole == GroupRole.owner;
    final isAdminOrOwner = isOwner || group.callerRole == GroupRole.admin;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // Header Profile Section
        Center(
          child: Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: AppColors.softVioletShadow,
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: GroupAvatar(
              name: group.name,
              radius: 64,
              avatarStorageKey: group.avatarStorageKey,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          group.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        if (group.description?.trim().isNotEmpty ?? false)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              group.description!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(height: 24),
        if (group.status == GroupStatus.archived)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              border: Border.all(color: Colors.amber.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.archive_outlined, color: Colors.amber.shade900),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    AppStrings.groupArchivedBanner,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (leaveTransferRequired)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.errorContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Vui lòng chuyển quyền trưởng nhóm trước khi rời nhóm.',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        // Stats / Bento Row
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.groups,
                iconColor: AppColors.primary,
                value: memberCount?.toString() ?? '—',
                label: 'THÀNH VIÊN',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.event,
                iconColor: AppColors.secondary,
                value: "Est. '${group.createdAt.year % 100}",
                label: 'NGÀY TẠO',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Group Admin / Owner Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: AppColors.softVioletShadow,
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primaryContainer.withValues(
                  alpha: 0.1,
                ),
                child: const Icon(Icons.person, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOwner ? 'Nhóm trưởng (Owner)' : 'Ban Quản trị',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const Text(
                      'Group Admin',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mail_outline,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Action Links Bento Container
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: AppColors.softVioletShadow,
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              if (isAdminOrOwner) ...[
                if (onInviteLinks != null) ...[
                  _ActionTile(
                    icon: Icons.link,
                    iconColor: AppColors.primary,
                    title: 'Liên kết mời',
                    onTap: onInviteLinks!,
                  ),
                  const Divider(height: 1),
                ],
                if (onJoinRequests != null) ...[
                  _ActionTile(
                    icon: Icons.person_add,
                    iconColor: AppColors.primary,
                    title: 'Yêu cầu tham gia',
                    onTap: onJoinRequests!,
                  ),
                  const Divider(height: 1),
                ],
                if (onBans != null) ...[
                  _ActionTile(
                    icon: Icons.block,
                    iconColor: AppColors.outline,
                    title: 'Danh sách chặn',
                    onTap: onBans!,
                  ),
                  const Divider(height: 1),
                ],
              ],
              _ActionTile(
                icon: Icons.edit_outlined,
                iconColor: AppColors.onSurfaceVariant,
                title: 'Sửa thông tin nhóm',
                onTap: onEdit,
              ),
              const Divider(height: 1),
              _ActionTile(
                icon: Icons.groups_outlined,
                iconColor: AppColors.onSurfaceVariant,
                title: 'Thành viên nhóm',
                onTap: onMembers,
              ),
              const Divider(height: 1),
              _ActionTile(
                icon: Icons.settings_outlined,
                iconColor: AppColors.onSurfaceVariant,
                title: 'Cài đặt nhóm',
                onTap: onSettings,
              ),
              const Divider(height: 1),
              if (onActivities != null) ...[
                _ActionTile(
                  icon: Icons.event_outlined,
                  iconColor: AppColors.onSurfaceVariant,
                  title: 'Hoạt động',
                  onTap: onActivities!,
                ),
                const Divider(height: 1),
              ],
              if (onExpenses != null) ...[
                _ActionTile(
                  icon: Icons.receipt_long_outlined,
                  iconColor: AppColors.primary,
                  title: 'Chi tiêu',
                  onTap: onExpenses!,
                ),
                const Divider(height: 1),
              ],
              if (onSettlements != null) ...[
                _ActionTile(
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: AppColors.primary,
                  title: 'Thanh toán công nợ',
                  onTap: onSettlements!,
                ),
                const Divider(height: 1),
              ],
              if (onFund != null) ...[
                _ActionTile(
                  icon: Icons.savings_outlined,
                  iconColor: AppColors.primary,
                  title: 'Quỹ nhóm',
                  onTap: onFund!,
                ),
                const Divider(height: 1),
              ],
              if (onNotificationMute != null) ...[
                _ActionTile(
                  icon: Icons.notifications_off_outlined,
                  iconColor: AppColors.primary,
                  title: 'Tắt thông báo nhóm',
                  onTap: onNotificationMute!,
                ),
                const Divider(height: 1),
              ],
              if (onChat != null) ...[
                _ActionTile(
                  icon: Icons.chat_bubble_outline,
                  iconColor: AppColors.primary,
                  title: 'Trò chuyện',
                  onTap: onChat!,
                ),
                const Divider(height: 1),
              ],
              _ActionTile(
                icon: Icons.history,
                iconColor: AppColors.onSurfaceVariant,
                title: 'Nhật ký nhóm',
                onTap: onActivityLog,
              ),
              if (isOwner) ...[
                if (group.status == GroupStatus.active &&
                    onArchive != null) ...[
                  const Divider(height: 1),
                  _ActionTile(
                    icon: Icons.archive_outlined,
                    iconColor: Colors.amber.shade700,
                    title: AppStrings.archiveGroup,
                    onTap: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text(
                            AppStrings.archiveGroupConfirmTitle,
                          ),
                          content: const Text(
                            AppStrings.archiveGroupConfirmMessage,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text(AppStrings.cancel),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber.shade800,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text(AppStrings.archiveGroup),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) onArchive!();
                    },
                  ),
                ],
                if (group.status == GroupStatus.archived &&
                    onRestore != null) ...[
                  const Divider(height: 1),
                  _ActionTile(
                    icon: Icons.unarchive_outlined,
                    iconColor: Colors.green.shade700,
                    title: AppStrings.restoreGroup,
                    onTap: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text(
                            AppStrings.restoreGroupConfirmTitle,
                          ),
                          content: const Text(
                            AppStrings.restoreGroupConfirmMessage,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text(AppStrings.cancel),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text(AppStrings.restoreGroup),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) onRestore!();
                    },
                  ),
                ],
                if (onDelete != null) ...[
                  const Divider(height: 1),
                  _ActionTile(
                    icon: Icons.delete_forever,
                    iconColor: AppColors.error,
                    title: 'Xóa nhóm',
                    titleColor: AppColors.error,
                    onTap: onDelete!,
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Danger Zone: Leave Group
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error.withValues(alpha: 0.1),
            foregroundColor: AppColors.error,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            minimumSize: const Size.fromHeight(50),
          ),
          onPressed: onLeave,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.logout, size: 20),
              SizedBox(width: 8),
              Text(
                'Rời nhóm',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: AppColors.softVioletShadow,
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: iconColor),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Color? titleColor;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.titleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: titleColor ?? AppColors.onSurface,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          size: 20,
          color: AppColors.onSurfaceVariant,
        ),
        onTap: onTap,
      ),
    );
  }
}
