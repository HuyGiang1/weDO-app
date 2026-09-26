import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/utils/date_time_formatter.dart';
import '../../data/group_failure.dart';
import '../../application/group_admission_controllers.dart';
import '../../application/group_management_controllers.dart';
import '../../data/models/group_models.dart';
import '../widgets/group_widgets.dart';

String _failureText(Object? failure) {
  if (failure == null) return '';
  if (failure is GroupFailure) return failure.toVietnameseMessage();
  return AppStrings.groupActionFailed;
}

class MyGroupInvitationsScreen extends StatefulWidget {
  final GroupInvitationsController controller;
  final VoidCallback? onAccepted;
  const MyGroupInvitationsScreen({
    super.key,
    required this.controller,
    this.onAccepted,
  });

  @override
  State<MyGroupInvitationsScreen> createState() =>
      _MyGroupInvitationsScreenState();
}

class _MyGroupInvitationsScreenState extends State<MyGroupInvitationsScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'WeDo',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: ValueListenableBuilder<GroupAsyncState<List<GroupInvitationResponse>>>(
        valueListenable: widget.controller,
        builder: (context, state, _) {
          if (state.loading && state.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = state.data ?? const [];
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mail_outline,
                      size: 40,
                      color: AppColors.outline,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Không có lời mời nào',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Các lời mời vào nhóm của bạn sẽ xuất hiện ở đây.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // Header Section
              const Text(
                'Lời mời vào nhóm',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Bạn có ${items.length} lời mời đang chờ xử lý.',
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              // List of Invitation Cards
              ...items.map((inv) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.softVioletShadow,
                        blurRadius: 20,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.groups_rounded,
                                size: 36,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  inv.groupId,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.person,
                                      size: 14,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text.rich(
                                        TextSpan(
                                          children: [
                                            const TextSpan(text: 'Được mời bởi '),
                                            TextSpan(
                                              text: inv.inviterUserId,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Gửi: ${inv.createdAt.toLocal().toString().split('.').first}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.onPrimary,
                                elevation: 0,
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () async {
                                final ok = await widget.controller.accept(inv.id);
                                if (ok && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Joined group successfully!'),
                                    ),
                                  );
                                  widget.onAccepted?.call();
                                }
                              },
                              child: const Text(
                                'Chấp nhận',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.surfaceContainerHigh,
                                foregroundColor: AppColors.onSurface,
                                elevation: 0,
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () async {
                                final ok = await widget.controller.decline(inv.id);
                                if (ok && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Invitation declined'),
                                    ),
                                  );
                                }
                              },
                              child: const Text(
                                'Từ chối',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class JoinByInviteCodeScreen extends StatefulWidget {
  final JoinByCodeController controller;
  final VoidCallback? onJoined;
  const JoinByInviteCodeScreen({
    super.key,
    required this.controller,
    this.onJoined,
  });

  @override
  State<JoinByInviteCodeScreen> createState() => _JoinByInviteCodeScreenState();
}

class _JoinByInviteCodeScreenState extends State<JoinByInviteCodeScreen> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Group by Code')),
      body: ValueListenableBuilder<GroupAsyncState<GroupInviteSummaryResponse>>(
        valueListenable: widget.controller,
        builder: (context, state, _) {
          final summary = state.data;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Invite Code',
                  hintText: 'Enter 8-character invite code',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.vpn_key),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: state.loading
                    ? null
                    : () {
                        final code = _codeController.text.trim();
                        if (code.isNotEmpty) {
                          widget.controller.resolve(code);
                        }
                      },
                icon: const Icon(Icons.search),
                label: const Text('Preview Group'),
              ),
              if (state.loading) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
              ],
              if (summary != null) ...[
                const SizedBox(height: 24),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        GroupAvatar(name: summary.groupName, radius: 40),
                        const SizedBox(height: 12),
                        Text(
                          summary.groupName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (summary.groupDescription?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 8),
                          Text(
                            summary.groupDescription!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Column(
                              children: [
                                const Text(
                                  'Members',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  '${summary.activeMemberCount}/100',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                const Text(
                                  'Admission',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Chip(
                                  label: Text(
                                    summary.joinPolicy == GroupJoinPolicy.autoJoin
                                        ? 'Auto Join'
                                        : 'Approval Required',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  backgroundColor: summary.joinPolicy ==
                                          GroupJoinPolicy.autoJoin
                                      ? Colors.green.shade50
                                      : Colors.amber.shade50,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: state.loading
                                ? null
                                : () async {
                                    final ok = await widget.controller.join(
                                      _codeController.text.trim(),
                                    );
                                    if (ok && context.mounted) {
                                      final msg = summary.joinPolicy ==
                                              GroupJoinPolicy.autoJoin
                                          ? 'Joined group successfully!'
                                          : 'Join request submitted! Awaiting admin approval.';
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(msg)),
                                      );
                                      widget.onJoined?.call();
                                      Navigator.of(context).pop();
                                    }
                                  },
                            child: Text(
                              summary.joinPolicy == GroupJoinPolicy.autoJoin
                                  ? 'Join Group'
                                  : 'Request to Join',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (state.failure != null) ...[
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    _failureText(state.failure),
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class GroupInviteLinksScreen extends StatefulWidget {
  final String groupId;
  final InviteLinksController controller;
  const GroupInviteLinksScreen({
    super.key,
    required this.groupId,
    required this.controller,
  });

  @override
  State<GroupInviteLinksScreen> createState() => _GroupInviteLinksScreenState();
}

class _GroupInviteLinksScreenState extends State<GroupInviteLinksScreen> {
  InviteLinkResponse? _defaultLink;
  bool _loadingDefault = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loadingDefault = true);
    final def = await widget.controller.getDefault(widget.groupId);
    if (mounted) {
      setState(() {
        _defaultLink = def;
        _loadingDefault = false;
      });
    }
    await widget.controller.load(widget.groupId);
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showCreateDialog() {
    final maxUsesController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.createCustomInviteLink),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: maxUsesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Số lượt tham gia tối đa (tùy chọn)',
                hintText: 'Để trống nếu không giới hạn',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final max = int.tryParse(maxUsesController.text.trim());
              Navigator.of(ctx).pop();
              await widget.controller.create(
                widget.groupId,
                CreateInviteLinkRequest(maxUses: max),
              );
              await _loadData();
            },
            child: const Text(AppStrings.confirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: true,
        title: const Text(
          AppStrings.groupInviteLinkTitle,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: ValueListenableBuilder<GroupAsyncState<List<InviteLinkResponse>>>(
        valueListenable: widget.controller,
        builder: (context, state, _) {
          final items = state.data ?? const [];
          // Filter other custom links (exclude the current default link from advanced list if identical)
          final customLinks = items.where((link) => link.id != _defaultLink?.id).toList();

          return RefreshIndicator(
            onRefresh: _loadData,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                if (state.failure != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _failureText(state.failure),
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),

                // Primary Default Invite Link Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A630ED4),
                        blurRadius: 20,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.link_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.groupInviteLinkTitle,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  AppStrings.groupInviteLinkSubtitle,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      if (_loadingDefault)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 12),
                                Text('Đang tải liên kết mời...'),
                              ],
                            ),
                          ),
                        )
                      else if (_defaultLink != null) ...[
                        // Link display box
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'https://wedo.app/inv/${_defaultLink!.inviteCode.toLowerCase()}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.primary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 20, color: AppColors.primary),
                                tooltip: AppStrings.copy,
                                onPressed: () => _copyToClipboard(
                                  'https://wedo.app/inv/${_defaultLink!.inviteCode.toLowerCase()}',
                                  AppStrings.copied,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Prominent Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                label: const Text(
                                  AppStrings.copyInviteLink,
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                onPressed: () => _copyToClipboard(
                                  'https://wedo.app/inv/${_defaultLink!.inviteCode.toLowerCase()}',
                                  AppStrings.copied,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(color: AppColors.primary),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: const Icon(Icons.share_rounded, size: 18),
                                label: const Text(
                                  AppStrings.shareInviteLink,
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                onPressed: () => _copyToClipboard(
                                  'https://wedo.app/inv/${_defaultLink!.inviteCode.toLowerCase()}',
                                  'Đã sao chép liên kết để chia sẻ!',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            AppStrings.noActiveInviteLink,
                            style: TextStyle(color: AppColors.onSurfaceVariant),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _loadData,
                          child: const Text(AppStrings.retry),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Progressive Disclosure: Advanced Multi-Link Management
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A630ED4),
                        blurRadius: 16,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      leading: const Icon(Icons.tune_rounded, color: AppColors.onSurfaceVariant),
                      title: const Text(
                        AppStrings.advancedInviteLinks,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                      ),
                      subtitle: const Text(
                        'Tùy chỉnh thời hạn hoặc số lượt tham gia',
                        style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        const Divider(height: 1, color: AppColors.surfaceContainerHigh),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Các liên kết khác',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text(AppStrings.createCustomInviteLink),
                              onPressed: _showCreateDialog,
                            ),
                          ],
                        ),
                        if (customLinks.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text(
                                'Chưa có liên kết tùy chỉnh nào.',
                                style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
                              ),
                            ),
                          )
                        else
                          ...customLinks.map((link) {
                            final isExpired = link.isExpired;
                            final isRevoked = link.isRevoked;
                            final isActive = !isExpired && !isRevoked;

                            return Container(
                              margin: const EdgeInsets.only(top: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.outlineVariant.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        link.inviteCode.toUpperCase(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          letterSpacing: 1.2,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? AppColors.primaryContainer.withValues(alpha: 0.2)
                                              : AppColors.surfaceContainerHigh,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isActive
                                              ? 'Hoạt động'
                                              : (isRevoked ? 'Đã thu hồi' : 'Hết hạn'),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isActive ? AppColors.primary : AppColors.outline,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Lượt dùng: ${link.usesCount} / ${link.maxUses ?? 'Không giới hạn'}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                                  ),
                                  if (link.expiresAt != null)
                                    Text(
                                      'Hết hạn: ${AppDateTimeFormatter.formatDateTime(link.expiresAt!)}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                                    ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        icon: const Icon(Icons.copy, size: 14),
                                        label: const Text('Sao chép'),
                                        onPressed: () => _copyToClipboard(
                                          'https://wedo.app/inv/${link.inviteCode.toLowerCase()}',
                                          AppStrings.copied,
                                        ),
                                      ),
                                      if (isActive) ...[
                                        const SizedBox(width: 8),
                                        TextButton(
                                          style: TextButton.styleFrom(foregroundColor: AppColors.error),
                                          onPressed: () async {
                                            await widget.controller.revoke(widget.groupId, link.id);
                                            await _loadData();
                                          },
                                          child: const Text('Thu hồi'),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class GroupJoinRequestsScreen extends StatefulWidget {
  final String groupId;
  final JoinRequestsController controller;
  const GroupJoinRequestsScreen({
    super.key,
    required this.groupId,
    required this.controller,
  });

  @override
  State<GroupJoinRequestsScreen> createState() =>
      _GroupJoinRequestsScreenState();
}

class _GroupJoinRequestsScreenState extends State<GroupJoinRequestsScreen> {
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
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'WeDo',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: ValueListenableBuilder<GroupAsyncState<List<JoinRequestResponse>>>(
        valueListenable: widget.controller,
        builder: (context, state, _) {
          if (state.loading && state.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = state.data ?? const [];
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_add_disabled,
                      size: 36,
                      color: AppColors.outline,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'No pending join requests',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // Header Section
              const Text(
                'Yêu cầu tham gia',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Bạn có ${items.length} yêu cầu đang chờ phê duyệt cho nhóm.',
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              // Requests list
              ...items.map((req) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.surfaceContainer,
                            child: const Icon(
                              Icons.person,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  req.requesterUserId,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '@${req.requesterUserId} • ${req.createdAt.toLocal().toString().split('.').first}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.group,
                              size: 16,
                              color: AppColors.secondary,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Đang chờ phê duyệt',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.surfaceContainerHighest,
                                foregroundColor: AppColors.onSurface,
                                elevation: 0,
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(vertical: 11),
                              ),
                              onPressed: () => widget.controller.reject(
                                widget.groupId,
                                req.id,
                              ),
                              child: const Text(
                                'Từ chối',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.onPrimary,
                                elevation: 1,
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(vertical: 11),
                              ),
                              onPressed: () => widget.controller.approve(
                                widget.groupId,
                                req.id,
                              ),
                              child: const Text(
                                'Duyệt',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class GroupBansScreen extends StatefulWidget {
  final String groupId;
  final GroupBansController controller;
  const GroupBansScreen({
    super.key,
    required this.groupId,
    required this.controller,
  });

  @override
  State<GroupBansScreen> createState() => _GroupBansScreenState();
}

class _GroupBansScreenState extends State<GroupBansScreen> {
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
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Ban List',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ),
      body: ValueListenableBuilder<GroupAsyncState<List<GroupBanResponse>>>(
        valueListenable: widget.controller,
        builder: (context, state, _) {
          if (state.loading && state.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = state.data ?? const [];
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.block,
                      size: 36,
                      color: AppColors.outline,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'No banned users in this group',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // Header Section
              const Text(
                'Banned Users',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Review and manage users who have been restricted from WeDo groups.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              ...items.map((ban) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
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
                        backgroundColor: AppColors.surfaceContainerLow,
                        child: const Icon(
                          Icons.person,
                          color: AppColors.outline,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ban.bannedUserId,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Banned: ${ban.createdAt.toLocal().toString().split('.').first}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(
                                  Icons.shield_outlined,
                                  size: 14,
                                  color: AppColors.outline,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    ban.reason ?? 'By Admin',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.outline,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          foregroundColor: AppColors.primary,
                          elevation: 0,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        onPressed: () async {
                          final ok = await widget.controller.unban(
                            widget.groupId,
                            ban.bannedUserId,
                          );
                          if (ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('User unbanned')),
                            );
                          }
                        },
                        child: const Text(
                          'Unban',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
