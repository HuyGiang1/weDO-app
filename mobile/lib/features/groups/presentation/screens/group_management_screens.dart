// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use

import 'package:flutter/material.dart';

import '../../application/group_management_controllers.dart';
import '../../data/models/group_models.dart';
import '../widgets/group_widgets.dart';

String _failureText(Object? failure) =>
    failure == null ? '' : 'Unable to complete this group action.';

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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit Group')),
    body: ValueListenableBuilder<GroupAsyncState<GroupDetail>>(
      valueListenable: widget.controller,
      builder: (context, state, _) {
        final group = state.data;
        if (group != null && !_seeded) {
          _seeded = true;
          _name.text = group.name;
          _description.text = group.description ?? '';
        }
        if (state.loading && group == null)
          return const Center(child: CircularProgressIndicator());
        return Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: InkWell(
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Group avatar upload is not available.'),
                    ),
                  ),
                  child: GroupAvatar(
                    name: _name.text.isEmpty ? '?' : _name.text,
                    radius: 56,
                  ),
                ),
              ),
              TextFormField(
                controller: _name,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Group name'),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Group name is required'
                    : null,
              ),
              TextFormField(
                controller: _description,
                maxLength: 500,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              if (state.failure != null) Text(_failureText(state.failure)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: state.loading
                    ? null
                    : () async {
                        if (!_form.currentState!.validate()) return;
                        final r = await widget.controller.save(
                          widget.groupId,
                          UpdateGroupRequest(
                            name: _name.text.trim(),
                            description: _description.text.trim(),
                          ),
                        );
                        if (r != null && context.mounted)
                          Navigator.of(context).pop(r);
                      },
                child: const Text('Save changes'),
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
            if (canKick)
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
    appBar: AppBar(title: const Text('Group Permissions')),
    body: ValueListenableBuilder<GroupAsyncState<GroupPermissionsData>>(
      valueListenable: widget.controller,
      builder: (c, s, _) {
        final d = s.data;
        if (s.loading && d == null)
          return const Center(child: CircularProgressIndicator());
        if (d == null) return Center(child: Text(_failureText(s.failure)));
        final owner = d.group.callerRole == GroupRole.owner;
        final x = d.settings;
        Future<void> save(UpdateGroupSettingsRequest q) async {
          await widget.controller.save(widget.groupId, q);
        }

        return ListView(
          children: [
            SwitchListTile(
              value: x.memberModifyInfoAllowed,
              onChanged: owner
                  ? (v) => save(
                      UpdateGroupSettingsRequest(memberModifyInfoAllowed: v),
                    )
                  : null,
              title: const Text('Members can edit group info'),
            ),
            SwitchListTile(
              value: x.memberCreateActivityAllowed,
              onChanged: owner
                  ? (v) => save(
                      UpdateGroupSettingsRequest(
                        memberCreateActivityAllowed: v,
                      ),
                    )
                  : null,
              title: const Text('Members can create activities'),
            ),
            SwitchListTile(
              value: x.memberPinMessageAllowed,
              onChanged: owner
                  ? (v) => save(
                      UpdateGroupSettingsRequest(memberPinMessageAllowed: v),
                    )
                  : null,
              title: const Text('Members can pin messages'),
            ),
            DropdownButtonFormField<GroupJoinPolicy>(
              value: x.joinPolicy,
              onChanged: owner
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
                            ? 'Auto join'
                            : 'Approval required',
                      ),
                    ),
                  )
                  .toList(),
              decoration: const InputDecoration(labelText: 'Join policy'),
            ),
            DropdownButtonFormField<ChatHistoryPolicy>(
              value: x.chatHistoryPolicy,
              onChanged: owner
                  ? (v) {
                      if (v != null)
                        save(UpdateGroupSettingsRequest(chatHistoryPolicy: v));
                    }
                  : null,
              items: ChatHistoryPolicy.values
                  .map(
                    (v) => DropdownMenuItem(
                      value: v,
                      child: Text(
                        v == ChatHistoryPolicy.fullHistory
                            ? 'Full history'
                            : 'From join time',
                      ),
                    ),
                  )
                  .toList(),
              decoration: const InputDecoration(labelText: 'Chat history'),
            ),
            ListTile(
              title: const Text('Manage admins'),
              trailing: const Icon(Icons.chevron_right),
              onTap: widget.onAdmins,
            ),
            ListTile(
              title: const Text('Transfer ownership'),
              trailing: const Icon(Icons.chevron_right),
              onTap: owner ? widget.onTransfer : null,
            ),
            if (s.failure != null) Text(_failureText(s.failure)),
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
