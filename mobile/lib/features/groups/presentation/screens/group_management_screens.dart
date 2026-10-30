import '../../../../app/theme/app_theme.dart';
import '../../../../core/ui/widgets/app_management.dart';
// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use

import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../../../core/realtime/realtime_binding.dart';
import '../../../../core/l10n/domain_labels.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../data/group_failure.dart';
import '../../application/group_management_controllers.dart';
import '../../data/models/group_models.dart';
import '../widgets/group_widgets.dart';

String _failureText(Object? failure) {
  if (failure == null) return '';
  if (failure is GroupFailure) return failure.toVietnameseMessage();
  return AppStrings.groupActionFailed;
}

class EditGroupScreen extends StatefulWidget {
  final String groupId;
  final EditGroupController controller;
  const EditGroupScreen({
    super.key,
    required this.groupId,
    required this.controller,
  });
  @override
  State<EditGroupScreen> createState() => _EditGroupScreenState();
}

class _EditGroupScreenState extends State<EditGroupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  bool _seeded = false;
  Uint8List? _previewBytes;
  String? _avatarStorageKey;
  String? _savedAvatarStorageKey;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    widget.controller.load(widget.groupId);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar(bool isArchived) async {
    if (isArchived || _isUploadingAvatar) return;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (!mounted || picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chọn ảnh nhỏ hơn 5 MiB.')),
        );
        return;
      }
      setState(() => _isUploadingAvatar = true);

      final ext = picked.name.split('.').last.toLowerCase();
      final contentType =
          picked.mimeType ??
          switch (ext) {
            'png' => 'image/png',
            'webp' => 'image/webp',
            'jpg' || 'jpeg' => 'image/jpeg',
            _ => '',
          };
      if (!const {
        'image/jpeg',
        'image/png',
        'image/webp',
      }.contains(contentType)) {
        setState(() => _isUploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chọn ảnh JPEG, PNG hoặc WebP.')),
        );
        return;
      }

      final storageKey = await widget.controller.uploadAvatar(
        groupId: widget.groupId,
        bytes: bytes,
        filename: picked.name.isEmpty ? 'avatar.jpg' : picked.name,
        contentType: contentType,
      );

      if (!mounted) return;

      if (storageKey != null) {
        setState(() {
          _avatarStorageKey = storageKey;
          _previewBytes = bytes;
          _isUploadingAvatar = false;
        });
      } else {
        setState(() {
          _previewBytes = null;
          _avatarStorageKey = _savedAvatarStorageKey;
          _isUploadingAvatar = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể tải ảnh lên. Vui lòng thử lại.'),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _previewBytes = null;
        _avatarStorageKey = _savedAvatarStorageKey;
        _isUploadingAvatar = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể tải ảnh lên. Vui lòng thử lại.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sửa thông tin nhóm')),
    body: ValueListenableBuilder<GroupAsyncState<GroupDetail>>(
      valueListenable: widget.controller,
      builder: (context, state, _) {
        final group = state.data;
        if (group != null && !_seeded) {
          _seeded = true;
          _name.text = group.name;
          _description.text = group.description ?? '';
          _avatarStorageKey = group.avatarStorageKey;
          _savedAvatarStorageKey = group.avatarStorageKey;
        }
        if (state.loading && group == null)
          return const Center(child: CircularProgressIndicator());

        final isArchived = group?.status == GroupStatus.archived;

        return Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (isArchived)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppSemanticColors.of(context).warning.withValues(alpha: .08),
                    border: Border.all(color: AppSemanticColors.of(context).warning.withValues(alpha: .3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppSemanticColors.of(context).warning),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          AppStrings.groupArchivedCannotMutate,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Center(
                child: Column(
                  children: [
                    Text(
                      'Ảnh nhóm',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(56),
                          onTap: (isArchived || _isUploadingAvatar)
                              ? null
                              : () => _pickAndUploadAvatar(isArchived),
                          child: GroupAvatar(
                            name: _name.text.isEmpty ? '?' : _name.text,
                            radius: 56,
                            avatarStorageKey: _avatarStorageKey,
                            imageBytes: _previewBytes,
                          ),
                        ),
                        if (_isUploadingAvatar)
                          Container(
                            width: 112,
                            height: 112,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.4),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_isUploadingAvatar)
                      const Text(
                        'Đang tải ảnh...',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      )
                    else
                      TextButton.icon(
                        onPressed: isArchived
                            ? null
                            : () => _pickAndUploadAvatar(isArchived),
                        icon: const Icon(Icons.photo_camera_outlined, size: 18),
                        label: Text(
                          (_avatarStorageKey != null || _previewBytes != null)
                              ? 'Đổi ảnh'
                              : 'Chọn ảnh',
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                maxLength: 100,
                enabled: !isArchived,
                decoration: const InputDecoration(labelText: 'Tên nhóm'),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Tên nhóm không được để trống'
                    : null,
              ),
              TextFormField(
                controller: _description,
                maxLength: 500,
                maxLines: 4,
                enabled: !isArchived,
                decoration: const InputDecoration(labelText: 'Mô tả nhóm'),
              ),
              if (state.failure != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _failureText(state.failure),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: (state.loading || isArchived || _isUploadingAvatar)
                    ? null
                    : () async {
                        if (!_form.currentState!.validate()) return;
                        final r = await widget.controller.save(
                          widget.groupId,
                          UpdateGroupRequest(
                            name: _name.text.trim(),
                            description: _description.text.trim(),
                            avatarStorageKey: _avatarStorageKey,
                          ),
                        );
                        if (r != null && context.mounted)
                          Navigator.of(context).pop(r);
                        else if (context.mounted) {
                          setState(() {
                            _avatarStorageKey = _savedAvatarStorageKey;
                            _previewBytes = null;
                          });
                        }
                      },
                child: const Text('Lưu thay đổi'),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class GroupMembersScreen extends StatefulWidget {
  final String groupId;
  final GroupMembersController controller;
  final ValueChanged<String> onMember;
  const GroupMembersScreen({
    super.key,
    required this.groupId,
    required this.controller,
    required this.onMember,
  });
  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> with RealtimeBinding<GroupMembersScreen> {
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
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Thành viên nhóm')),
    body: ValueListenableBuilder<GroupAsyncState<List<GroupMember>>>(
      valueListenable: widget.controller,
      builder: (c, s, _) {
        if (s.loading && s.data == null)
          return const Center(child: CircularProgressIndicator());
        final members = s.data ?? const <GroupMember>[];
        return ListView(
          children: [
            for (final m in members) ...[
              AppSurface(child: AppManagementRow(
                onTap: () => widget.onMember(m.userId),
                icon: Icons.person_outline,
                leading: GroupAvatar(name: m.displayName, avatarStorageKey: m.avatarStorageKey, radius: 20),
                title: m.displayName, subtitle: '@${m.username}', status: m.role.label,
              )),
              const SizedBox(height: 8),
            ],
            if (s.failure != null) Center(child: Text(_failureText(s.failure))),
          ],
        );
      },
    ),
  );
}

class MemberManagementScreen extends StatefulWidget {
  final String groupId, userId;
  final MemberManagementController controller;
  final VoidCallback onKicked;
  const MemberManagementScreen({
    super.key,
    required this.groupId,
    required this.userId,
    required this.controller,
    required this.onKicked,
  });
  @override
  State<MemberManagementScreen> createState() => _MemberManagementScreenState();
}

class _MemberManagementScreenState extends State<MemberManagementScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.load(widget.groupId, widget.userId);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Quản lý thành viên')),
    body: ValueListenableBuilder<GroupAsyncState<MemberManagementData>>(
      valueListenable: widget.controller,
      builder: (c, s, _) {
        final d = s.data;
        if (s.loading && d == null)
          return const Center(child: CircularProgressIndicator());
        if (d == null) return Center(child: Text(_failureText(s.failure)));
        final owner = d.group.callerRole == GroupRole.owner;
        final admin = d.group.callerRole == GroupRole.admin;
        final target = d.member;
        final canKick =
            (owner && target.role != GroupRole.owner) ||
            (admin && target.role == GroupRole.member);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ListTile(
              leading: GroupAvatar(name: target.displayName),
              title: Text(target.displayName),
              subtitle: Text('@${target.username}'),
              trailing: GroupRoleBadge(role: target.role),
            ),
            if (owner && target.role == GroupRole.member)
              ElevatedButton(
                onPressed: () =>
                    widget.controller.promote(widget.groupId, widget.userId),
                child: const Text('Bổ nhiệm quản trị viên'),
              ),
            if (owner && target.role == GroupRole.admin)
              OutlinedButton(
                onPressed: () =>
                    widget.controller.demote(widget.groupId, widget.userId),
                child: const Text('Gỡ quyền quản trị viên'),
              ),
            if (canKick) ...[
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: Theme.of(c).colorScheme.error),
                onPressed: () async {
                  if (await widget.controller.kick(
                        widget.groupId,
                        widget.userId,
                      ) &&
                      c.mounted)
                    widget.onKicked();
                },
                child: const Text('Xóa thành viên'),
              ),
              OutlinedButton(
                onPressed: () async {
                  final reasonController = TextEditingController();
                  final confirmed = await showDialog<bool>(
                    context: c,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Cấm thành viên'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Bạn có chắc muốn cấm ${target.displayName}?',
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: reasonController,
                            decoration: const InputDecoration(
                              labelText: 'Lý do (tùy chọn)',
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Hủy'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.error,
                          ),
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Cấm'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    final reason = reasonController.text.trim();
                    final ok = await widget.controller.ban(
                      widget.groupId,
                      widget.userId,
                      reason: reason.isEmpty ? null : reason,
                    );
                    if (ok && c.mounted) {
                      widget.onKicked();
                    }
                  }
                },
                child: Text(
                  'Cấm thành viên',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            if (s.failure != null) Text(_failureText(s.failure)),
          ],
        );
      },
    ),
  );
}

class GroupPermissionsScreen extends StatefulWidget {
  final String groupId;
  final GroupPermissionsController controller;
  final VoidCallback? onAdmins, onTransfer;
  const GroupPermissionsScreen({
    super.key,
    required this.groupId,
    required this.controller,
    this.onAdmins,
    this.onTransfer,
  });
  @override
  State<GroupPermissionsScreen> createState() => _GroupPermissionsScreenState();
}

class _GroupPermissionsScreenState extends State<GroupPermissionsScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.load(widget.groupId);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Cài đặt quyền nhóm')),
    body: ValueListenableBuilder<GroupAsyncState<GroupPermissionsData>>(
      valueListenable: widget.controller,
      builder: (c, s, _) {
        final d = s.data;
        if (s.loading && d == null)
          return const Center(child: CircularProgressIndicator());
        if (d == null) return Center(child: Text(_failureText(s.failure)));

        final isOwner = d.group.callerRole == GroupRole.owner;
        final isActive = d.group.status == GroupStatus.active;
        final canMutate = isOwner && isActive;
        final x = d.settings;

        Future<void> save(UpdateGroupSettingsRequest q) async {
          await widget.controller.save(widget.groupId, q);
        }

        return ListView(
          children: [
            if (!isActive)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppSemanticColors.of(context).warning.withValues(alpha: .08),
                  border: Border.all(color: AppSemanticColors.of(context).warning.withValues(alpha: .3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppSemanticColors.of(context).warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppStrings.groupArchivedCannotMutate,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (!isOwner)
              Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppStrings.groupOnlyOwnerCanChangeSettings,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            SwitchListTile(
              value: x.memberModifyInfoAllowed,
              onChanged: canMutate
                  ? (v) => save(
                      UpdateGroupSettingsRequest(memberModifyInfoAllowed: v),
                    )
                  : null,
              title: const Text('Thành viên có thể sửa thông tin nhóm'),
            ),
            SwitchListTile(
              value: x.memberCreateActivityAllowed,
              onChanged: canMutate
                  ? (v) => save(
                      UpdateGroupSettingsRequest(
                        memberCreateActivityAllowed: v,
                      ),
                    )
                  : null,
              title: const Text('Thành viên có thể tạo hoạt động'),
            ),
            SwitchListTile(
              value: x.memberPinMessageAllowed,
              onChanged: canMutate
                  ? (v) => save(
                      UpdateGroupSettingsRequest(memberPinMessageAllowed: v),
                    )
                  : null,
              title: const Text('Thành viên có thể ghim tin nhắn'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DropdownButtonFormField<GroupJoinPolicy>(
                value: x.joinPolicy,
                onChanged: canMutate
                    ? (v) {
                        if (v != null)
                          save(UpdateGroupSettingsRequest(joinPolicy: v));
                      }
                    : null,
                items: GroupJoinPolicy.values
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text(
                          v == GroupJoinPolicy.autoJoin
                              ? 'Tự do tham gia'
                              : 'Cần xét duyệt',
                        ),
                      ),
                    )
                    .toList(),
                decoration: const InputDecoration(
                  labelText: 'Hình thức tham gia nhóm',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DropdownButtonFormField<ChatHistoryPolicy>(
                value: x.chatHistoryPolicy,
                onChanged: canMutate
                    ? (v) {
                        if (v != null)
                          save(
                            UpdateGroupSettingsRequest(chatHistoryPolicy: v),
                          );
                      }
                    : null,
                items: ChatHistoryPolicy.values
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text(
                          v == ChatHistoryPolicy.fullHistory
                              ? 'Toàn bộ lịch sử'
                              : 'Từ khi tham gia',
                        ),
                      ),
                    )
                    .toList(),
                decoration: const InputDecoration(
                  labelText: 'Lịch sử trò chuyện',
                ),
              ),
            ),
            ListTile(
              title: const Text('Quản lý quản trị viên'),
              trailing: const Icon(Icons.chevron_right),
              onTap: isActive ? widget.onAdmins : null,
            ),
            ListTile(
              title: const Text('Chuyển quyền trưởng nhóm'),
              trailing: const Icon(Icons.chevron_right),
              onTap: canMutate ? widget.onTransfer : null,
            ),
            if (s.failure != null)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  border: Border.all(color: Theme.of(context).colorScheme.error.withValues(alpha: .3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _failureText(s.failure),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class GroupAdminManagementScreen extends StatefulWidget {
  final String groupId;
  final GroupAdminController controller;
  const GroupAdminManagementScreen({
    super.key,
    required this.groupId,
    required this.controller,
  });
  @override
  State<GroupAdminManagementScreen> createState() =>
      _GroupAdminManagementScreenState();
}

class _GroupAdminManagementScreenState
    extends State<GroupAdminManagementScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.load(widget.groupId);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Quản trị viên nhóm')),
    body: ValueListenableBuilder<GroupAsyncState<GroupAdminData>>(
      valueListenable: widget.controller,
      builder: (c, s, _) {
        final d = s.data;
        if (s.loading && d == null)
          return const Center(child: CircularProgressIndicator());
        if (d == null) return Center(child: Text(_failureText(s.failure)));
        final owner = d.group.callerRole == GroupRole.owner;
        return ListView(
          children: [
            for (final m in d.members)
              if (m.role != GroupRole.member)
                ListTile(
                  title: Text(m.displayName),
                  trailing: owner && m.role == GroupRole.admin
                      ? TextButton(
                          onPressed: () => widget.controller.demote(
                            widget.groupId,
                            m.userId,
                          ),
                          child: const Text('Gỡ quyền quản trị viên'),
                        )
                      : GroupRoleBadge(role: m.role),
                ),
            if (owner) ...[
              const Divider(),
              const Text('Thành viên'),
              for (final m in d.members)
                if (m.role == GroupRole.member)
                  ListTile(
                    title: Text(m.displayName),
                    trailing: TextButton(
                      onPressed: () =>
                          widget.controller.promote(widget.groupId, m.userId),
                      child: const Text('Bổ nhiệm quản trị viên'),
                    ),
                  ),
            ],
            if (s.failure != null) Text(_failureText(s.failure)),
          ],
        );
      },
    ),
  );
}

class TransferOwnershipScreen extends StatefulWidget {
  final String groupId;
  final TransferOwnershipController controller;
  final ValueChanged<GroupDetail> onTransferred;
  const TransferOwnershipScreen({
    super.key,
    required this.groupId,
    required this.controller,
    required this.onTransferred,
  });
  @override
  State<TransferOwnershipScreen> createState() =>
      _TransferOwnershipScreenState();
}

class _TransferOwnershipScreenState extends State<TransferOwnershipScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.load(widget.groupId);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Chuyển quyền chủ nhóm')),
    body: ValueListenableBuilder<GroupAsyncState<GroupAdminData>>(
      valueListenable: widget.controller,
      builder: (c, s, _) {
        final d = s.data;
        if (s.loading && d == null)
          return const Center(child: CircularProgressIndicator());
        if (d == null) return Center(child: Text(_failureText(s.failure)));
        return ListView(
          children: [
            if (d.group.callerRole != GroupRole.owner) const AppNotice('Chỉ trưởng nhóm có thể chuyển quyền.', tone: AppTone.warning),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Chọn thành viên hoặc quản trị viên đang hoạt động làm chủ nhóm mới.'),
            ),
            for (final m in d.members)
              if (d.group.callerRole == GroupRole.owner && m.role != GroupRole.owner)
                AppManagementRow(
                  icon: Icons.swap_horiz,
                  title: m.displayName,
                  subtitle: m.role.label,
                  onTap: () async {
                    final confirmed = await showDialog<bool>(context: c, builder: (dialog) => AlertDialog(title: const Text('Chuyển quyền trưởng nhóm?'), content: Text('Chuyển quyền trưởng nhóm cho ${m.displayName}.'), actions: [TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Hủy')), FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Xác nhận'))]));
                    if (confirmed != true || !c.mounted) return;
                    final r = await widget.controller.transfer(
                      widget.groupId,
                      m.userId,
                    );
                    if (r != null && c.mounted) widget.onTransferred(r);
                  },
                ),
            if (s.failure != null) Text(_failureText(s.failure)),
          ],
        );
      },
    ),
  );
}
