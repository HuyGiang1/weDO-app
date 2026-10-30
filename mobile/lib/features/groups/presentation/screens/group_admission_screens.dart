import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/realtime/realtime_binding.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/ui/widgets/app_management.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/links/wedo_deep_link.dart';
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

class _MyGroupInvitationsScreenState extends State<MyGroupInvitationsScreen> with RealtimeBinding<MyGroupInvitationsScreen> {
  @override
  String? get realtimeScope => 'user:self';
  @override
  String get realtimePrefix => 'GROUP_';
  @override
  Future<void> reloadRealtime() async { await widget.controller.load(); }

  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Lời mời vào nhóm',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
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
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mail_outline,
                      size: 40,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Không có lời mời nào',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Các lời mời vào nhóm của bạn sẽ xuất hiện ở đây.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              Text(
                'Lời mời vào nhóm',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Bạn có ${items.length} lời mời đang chờ xử lý.',
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              // List of Invitation Cards
              ...items.map((inv) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),

                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GroupAvatar(
                            name: inv.groupName ?? 'Nhóm',
                            avatarStorageKey: inv.groupAvatarStorageKey,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  inv.groupName?.trim().isNotEmpty == true
                                      ? inv.groupName!
                                      : 'Tên nhóm không khả dụng',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person,
                                      size: 14,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text.rich(
                                        TextSpan(
                                          children: [
                                            const TextSpan(text: 'Được mời bởi '),
                                            TextSpan(
                                              text: inv.inviterDisplayName?.trim().isNotEmpty == true
                                                  ? inv.inviterDisplayName!
                                                  : 'Tên người mời không khả dụng',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Gửi: ${inv.createdAt.toLocal().toString().split('.').first}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.outline,
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
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                elevation: 0,
                                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () async {
                                final ok = await widget.controller.accept(inv.id);
                                if (ok && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Đã tham gia nhóm!'),
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
                                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                                foregroundColor: Theme.of(context).colorScheme.onSurface,
                                elevation: 0,
                                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () async {
                                final ok = await widget.controller.decline(inv.id);
                                if (ok && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Đã từ chối lời mời'),
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
  final String? initialCode;
  final VoidCallback? onJoined;
  final ValueChanged<String>? onOpenGroup;
  const JoinByInviteCodeScreen({
    super.key,
    required this.controller,
    this.initialCode,
    this.onJoined,
    this.onOpenGroup,
  });

  @override
  State<JoinByInviteCodeScreen> createState() => _JoinByInviteCodeScreenState();
}

class _JoinByInviteCodeScreenState extends State<JoinByInviteCodeScreen> {
  final _codeController = TextEditingController();
  String? _localInputError;
  String? _resolvedCode;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCode?.trim();
    if (initial != null && initial.isNotEmpty) {
      _codeController.text = initial;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _handleResolve();
        }
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _handleResolve() {
    final raw = _codeController.text.trim();
    if (raw.isEmpty) return;
    final extracted = WeDoDeepLink.extractInviteCodeFromInput(raw);
    if (extracted == null) {
      setState(() {
        _localInputError = 'Liên kết mời hoặc mã mời không hợp lệ.';
      });
      return;
    }
    setState(() {
      _localInputError = null;
      _resolvedCode = extracted;
    });
    widget.controller.resolve(extracted);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tham gia nhóm bằng mã')),
      body: ValueListenableBuilder<GroupAsyncState<GroupInviteSummaryResponse>>(
        valueListenable: widget.controller,
        builder: (context, state, _) {
          final summary = state.data;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Mã mời',
                  hintText: 'Nhập mã mời hoặc dán liên kết mời weDO',
                  prefixIcon: Icon(Icons.vpn_key),
                ),
                onChanged: (_) {
                  if (_localInputError != null) {
                    setState(() => _localInputError = null);
                  }
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: state.loading ? null : _handleResolve,
                icon: const Icon(Icons.search),
                label: const Text('Xem trước nhóm'),
              ),
              if (_localInputError != null) ...[
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    _localInputError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ],
              if (state.loading) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
              ],
              if (summary != null && _localInputError == null) ...[
                const SizedBox(height: 24),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        GroupAvatar(
                          name: summary.groupName,
                          avatarStorageKey: summary.groupAvatarStorageKey,
                          radius: 40,
                        ),
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
                                  'Thành viên',
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
                                  'Hình thức tham gia',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Chip(
                                  label: Text(
                                    summary.joinPolicy == GroupJoinPolicy.autoJoin
                                        ? 'Tham gia trực tiếp'
                                        : 'Cần phê duyệt',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  backgroundColor: summary.joinPolicy ==
                                          GroupJoinPolicy.autoJoin
                                      ? Colors.green.shade50
                                      : AppSemanticColors.of(context).warning.withValues(alpha: .08),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (summary.alreadyMember) ...[
                          const Text('Bạn đã ở trong nhóm này.'),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: state.loading || widget.onOpenGroup == null ? null : () => widget.onOpenGroup!(summary.groupId),
                            icon: const Icon(Icons.group_outlined),
                            label: const Text('Vào nhóm'),
                          ),
                        ] else if (summary.requestPending)
                          const Text('Yêu cầu của bạn đang chờ duyệt.')
                        else SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: state.loading
                                ? null
                                : () async {
                                    final code =
                                        WeDoDeepLink.extractInviteCodeFromInput(
                                          _codeController.text,
                                        ) ??
                                        _resolvedCode ??
                                        _codeController.text.trim();
                                    final ok = await widget.controller.join(
                                      code,
                                    );
                                    if (ok && context.mounted) {
                                      final msg = summary.joinPolicy ==
                                              GroupJoinPolicy.autoJoin
                                          ? 'Đã tham gia nhóm!'
                                          : 'Đã gửi yêu cầu tham gia. Đang chờ phê duyệt.';
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(msg)),
                                      );
                                      widget.onJoined?.call();
                                      Navigator.of(context).pop();
                                    }
                                  },
                            child: Text(
                              summary.joinPolicy == GroupJoinPolicy.autoJoin
                                  ? 'Tham gia nhóm'
                                  : 'Yêu cầu tham gia',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (state.failure != null && _localInputError == null) ...[
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    _failureText(state.failure),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
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

  Future<void> _shareInviteLink(String inviteCode) async {
    final url = WeDoLinkConfig.groupInviteUrl(inviteCode);
    final shared = await WeDoPlatformLinks.shareText(
      url,
      subject: 'Lời mời tham gia nhóm weDO',
    );
    if (!shared && mounted) {
      _copyToClipboard(url, 'Đã sao chép liên kết để chia sẻ!');
    }
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: true,
        title: Text(
          AppStrings.groupInviteLinkTitle,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
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
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _failureText(state.failure),
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),

                // Primary Default Invite Link Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),

                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainer.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.link_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.groupInviteLinkTitle,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Quét mã hoặc mở liên kết để xem lời mời.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                        Text('Mã QR nhóm', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        Semantics(
                          label: 'Mã QR mời tham gia nhóm',
                          image: true,
                          excludeSemantics: true,
                          child: Center(
                            child: LayoutBuilder(
                              builder: (context, constraints) => QrImageView(
                                data: WeDoLinkConfig.groupInviteUrl(_defaultLink!.inviteCode),
                                size: constraints.maxWidth.clamp(0.0, 240.0).toDouble(),
                                padding: const EdgeInsets.all(16),
                                backgroundColor: Colors.white,
                                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text('Quét bằng weDO để mở lời mời. Việc tham gia tuân theo cài đặt nhóm.'),
                        const SizedBox(height: 16),
                        // Link display box
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  WeDoLinkConfig.groupInviteUrl(_defaultLink!.inviteCode),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.copy_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                                tooltip: AppStrings.copy,
                                onPressed: () => _copyToClipboard(
                                  WeDoLinkConfig.groupInviteUrl(_defaultLink!.inviteCode),
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
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                                  WeDoLinkConfig.groupInviteUrl(_defaultLink!.inviteCode),
                                  AppStrings.copied,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Theme.of(context).colorScheme.primary,
                                  side: BorderSide(color: Theme.of(context).colorScheme.primary),
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
                                onPressed: () => _shareInviteLink(_defaultLink!.inviteCode),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            AppStrings.noActiveInviteLink,
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),

                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: Material(
                      color: Theme.of(context).colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: ExpansionTile(
                      leading: Icon(Icons.tune_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      title: Text(
                        AppStrings.advancedInviteLinks,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        'Tùy chỉnh thời hạn hoặc số lượt tham gia',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        Divider(height: 1, color: Theme.of(context).colorScheme.surfaceContainerHigh),
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
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
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text(
                                'Chưa có liên kết tùy chỉnh nào.',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
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
                                color: Theme.of(context).colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(child: Text(
                                        link.inviteCode,
                                        maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          letterSpacing: 1.2,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      )),
                                      const SizedBox(width: 8),
                                      AppStatusLabel(isActive ? 'Hoạt động' : (isRevoked ? 'Đã thu hồi' : 'Hết hạn'), tone: isActive ? AppTone.success : AppTone.neutral, icon: isActive ? Icons.check_circle_outline : Icons.link_off),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Lượt dùng: ${link.usesCount} / ${link.maxUses ?? 'Không giới hạn'}',
                                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  ),
                                  if (link.expiresAt != null)
                                    Text(
                                      'Hết hạn: ${AppDateTimeFormatter.formatDateTime(link.expiresAt!)}',
                                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                    ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    alignment: WrapAlignment.end,
                                    spacing: 4,
                                    children: [
                                      TextButton.icon(
                                        icon: const Icon(Icons.copy, size: 14),
                                        label: const Text('Sao chép'),
                                        onPressed: () => _copyToClipboard(
                                          WeDoLinkConfig.groupInviteUrl(link.inviteCode),
                                          AppStrings.copied,
                                        ),
                                      ),
                                      TextButton.icon(
                                        icon: const Icon(Icons.share_rounded, size: 14),
                                        label: const Text('Chia sẻ'),
                                        onPressed: () => _shareInviteLink(link.inviteCode),
                                      ),
                                      if (isActive) ...[
                                        const SizedBox(width: 8),
                                        TextButton(
                                          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
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

class _GroupJoinRequestsScreenState extends State<GroupJoinRequestsScreen> with RealtimeBinding<GroupJoinRequestsScreen> {
  @override
  Set<String> get realtimeAdditionalScopes => const {'user:self'};
  @override
  String get realtimeAggregateId => widget.groupId;
  @override
  String? get realtimeScope => 'group:${widget.groupId}';
  @override
  String get realtimePrefix => 'GROUP_';
  @override
  Future<void> reloadRealtime() async { await widget.controller.load(widget.groupId); }

  @override
  void initState() {
    super.initState();
    widget.controller.load(widget.groupId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Yêu cầu tham gia',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
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
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_add_disabled,
                      size: 36,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Không có yêu cầu đang chờ duyệt',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
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
              Text(
                'Yêu cầu tham gia',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Bạn có ${items.length} yêu cầu đang chờ phê duyệt cho nhóm.',
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              // Requests list
              ...items.map((req) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),

                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GroupAvatar(
                            radius: 24,
                            name: req.userDisplayName ?? 'Người dùng',
                            avatarStorageKey: req.userAvatarStorageKey,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  req.userDisplayName?.trim().isNotEmpty == true
                                      ? req.userDisplayName!
                                      : 'Tên người yêu cầu chưa khả dụng',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Ngày gửi: ${req.createdAt.toLocal().toString().split('.').first}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                          color: Theme.of(context).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.group,
                              size: 16,
                              color: AppSemanticColors.of(context).warning,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Đang chờ phê duyệt',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                foregroundColor: Theme.of(context).colorScheme.onSurface,
                                elevation: 0,
                                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
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
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                elevation: 1,
                                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
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

class _GroupBansScreenState extends State<GroupBansScreen> with RealtimeBinding<GroupBansScreen> {
  @override
  String? get realtimeScope => 'group:${widget.groupId}';
  @override
  String get realtimePrefix => 'GROUP_';
  @override
  Future<void> reloadRealtime() async { await widget.controller.load(widget.groupId); }

  @override
  void initState() {
    super.initState();
    widget.controller.load(widget.groupId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Danh sách cấm',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
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
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.block,
                      size: 36,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Nhóm chưa có người dùng bị cấm',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
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
              Text(
                'Người dùng bị cấm',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Xem và quản lý người dùng bị cấm tham gia nhóm.',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              ...items.map((ban) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),

                  ),
                  child: Row(
                    children: [
                      GroupAvatar(
                        radius: 24,
                        name: ban.displayName ?? ban.username ?? 'Người dùng',
                        avatarStorageKey: ban.avatarStorageKey,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ban.displayName?.trim().isNotEmpty == true
                                  ? ban.displayName!
                                  : (ban.username?.trim().isNotEmpty == true
                                        ? '@${ban.username}'
                                        : 'Tên người dùng chưa khả dụng'),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Ngày cấm: ${ban.createdAt.toLocal().toString().split('.').first}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.shield_outlined,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    ban.reason ?? 'Không có lý do được cung cấp',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.outline,
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
                          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          foregroundColor: Theme.of(context).colorScheme.primary,
                          elevation: 0,
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        onPressed: () async {
                          final ok = await widget.controller.unban(
                            widget.groupId,
                            ban.bannedUserId,
                          );
                          if (ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Đã bỏ cấm người dùng')),
                            );
                          }
                        },
                        child: const Text(
                          'Bỏ cấm',
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
