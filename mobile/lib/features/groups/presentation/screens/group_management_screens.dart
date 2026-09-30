// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use

import 'dart:typed_data';

import 'package:flutter/material.dart';
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
          const SnackBar(content: Text('Choose an image smaller than 5 MiB.')),
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
          const SnackBar(content: Text('Choose a JPEG, PNG, or WebP image.')),
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
                    color: Colors.amber.shade50,
                    border: Border.all(color: Colors.amber.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber.shade900),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          AppStrings.groupArchivedCannotMutate,
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
              Center(
                child: Column(
                  children: [
                    Text(
                      'Ảnh nhóm',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
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
                    style: const TextStyle(
                      color: Colors.red,
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

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.load(widget.groupId);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Group Members')),
    body: ValueListenableBuilder<GroupAsyncState<List<GroupMember>>>(
      valueListenable: widget.controller,
      builder: (c, s, _) {
        if (s.loading && s.data == null)
          return const Center(child: CircularProgressIndicator());
        final members = s.data ?? const <GroupMember>[];
        return ListView(
          children: [
            for (final m in members)
              ListTile(
                onTap: () => widget.onMember(m.userId),
                leading: GroupAvatar(name: m.displayName),
                title: Text(m.displayName),
                subtitle: Text('@${m.username}'),
                trailing: GroupRoleBadge(role: m.role),
              ),
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
    appBar: AppBar(title: const Text('Member Management')),
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
                child: const Text('Make admin'),
              ),
            if (owner && target.role == GroupRole.admin)
              OutlinedButton(
                onPressed: () =>
                    widget.controller.demote(widget.groupId, widget.userId),
                child: const Text('Remove admin'),
              ),
            if (canKick) ...[
              OutlinedButton(
                onPressed: () async {
                  if (await widget.controller.kick(
                        widget.groupId,
                        widget.userId,
                      ) &&
                      c.mounted)
                    widget.onKicked();
                },
                child: const Text('Remove member'),
              ),
              OutlinedButton(
                onPressed: () async {
                  final reasonController = TextEditingController();
                  final confirmed = await showDialog<bool>(
                    context: c,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Ban Member'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Are you sure you want to ban ${target.displayName}?',
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: reasonController,
                            decoration: const InputDecoration(
                              labelText: 'Reason (optional)',
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Ban'),
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
                child: const Text(
                  'Ban member',
                  style: TextStyle(color: Colors.red),
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
                  color: Colors.amber.shade50,
                  border: Border.all(color: Colors.amber.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade900),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        AppStrings.groupArchivedCannotMutate,
                        style: TextStyle(
                          color: Colors.black87,
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
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, color: Colors.blue.shade800),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        AppStrings.groupOnlyOwnerCanChangeSettings,
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
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _failureText(s.failure),
                  style: TextStyle(
                    color: Colors.red.shade900,
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
    appBar: AppBar(title: const Text('Group Admins')),
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
                          child: const Text('Remove admin'),
                        )
                      : GroupRoleBadge(role: m.role),
                ),
            if (owner) ...[
              const Divider(),
              const Text('Members'),
              for (final m in d.members)
                if (m.role == GroupRole.member)
                  ListTile(
                    title: Text(m.displayName),
                    trailing: TextButton(
                      onPressed: () =>
                          widget.controller.promote(widget.groupId, m.userId),
                      child: const Text('Make admin'),
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
    appBar: AppBar(title: const Text('Transfer Ownership')),
    body: ValueListenableBuilder<GroupAsyncState<GroupAdminData>>(
      valueListenable: widget.controller,
      builder: (c, s, _) {
        final d = s.data;
        if (s.loading && d == null)
          return const Center(child: CircularProgressIndicator());
        if (d == null) return Center(child: Text(_failureText(s.failure)));
        return ListView(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Choose an active member or admin as the new owner.'),
            ),
            for (final m in d.members)
              if (m.role != GroupRole.owner)
                ListTile(
                  title: Text(m.displayName),
                  subtitle: Text(m.role.name.toUpperCase()),
                  onTap: () async {
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
