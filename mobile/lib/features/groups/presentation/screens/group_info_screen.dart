import 'package:flutter/material.dart';

import '../../application/group_detail_controller.dart';
import '../../data/group_failure.dart';
import '../../data/models/group_models.dart';
import '../widgets/group_widgets.dart';

class GroupInfoScreen extends StatefulWidget {
  final String groupId;
  final GroupDetailController controller;
  final VoidCallback onEdit, onMembers, onSettings, onActivityLog, onLeave;
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
      appBar: AppBar(centerTitle: true, title: const Text('Group Info')),
      bottomNavigationBar: const GroupsBottomNavigation(),
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
                label: const Text('Thu lai'),
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
      padding: const EdgeInsets.all(20),
      children: [
        Center(child: GroupAvatar(name: group.name, radius: 64)),
        const SizedBox(height: 16),
        Text(
          group.name,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        ),
        if (group.description?.trim().isNotEmpty ?? false)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(group.description!, textAlign: TextAlign.center),
          ),
        const SizedBox(height: 24),
        if (leaveTransferRequired)
          const Text('Transfer ownership before leaving this group.'),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.groups,
                value: memberCount?.toString() ?? '—',
                label: 'Members',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _StatCard(
                icon: Icons.event,
                value: 'Est. ${group.createdAt.year}',
                label: 'Created',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ListTile(
          leading: const Icon(Icons.edit),
          title: const Text('Edit Group'),
          onTap: onEdit,
        ),
        ListTile(
          leading: const Icon(Icons.groups),
          title: const Text('Group Members'),
          onTap: onMembers,
        ),
        if (isAdminOrOwner) ...[
          if (onInviteLinks != null)
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Invite Links'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onInviteLinks,
            ),
          if (onJoinRequests != null)
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Join Requests'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onJoinRequests,
            ),
          if (onBans != null)
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Banned Users'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onBans,
            ),
        ],
        ListTile(
          onTap: onSettings,
          leading: const Icon(Icons.settings),
          title: const Text('Group Settings'),
          trailing: const Icon(Icons.chevron_right),
        ),
        ListTile(
          onTap: onActivityLog,
          leading: const Icon(Icons.history),
          title: const Text('Activity Log'),
          trailing: const Icon(Icons.chevron_right),
        ),
        if (isOwner) ...[
          const Divider(height: 32),
          if (group.status == GroupStatus.active && onArchive != null)
            ListTile(
              leading: const Icon(Icons.archive, color: Colors.amber),
              title: const Text('Archive Group'),
              onTap: onArchive,
            ),
          if (group.status == GroupStatus.archived && onRestore != null)
            ListTile(
              leading: const Icon(Icons.unarchive, color: Colors.green),
              title: const Text('Restore Group'),
              onTap: onRestore,
            ),
          if (onDelete != null)
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text(
                'Delete Group',
                style: TextStyle(color: Colors.red),
              ),
              onTap: onDelete,
            ),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: OutlinedButton.icon(
            onPressed: onLeave,
            icon: const Icon(Icons.logout),
            label: const Text('Leave Group'),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Icon(icon),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        Text(label),
      ],
    ),
  );
}
