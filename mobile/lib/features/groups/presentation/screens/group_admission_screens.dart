import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../application/group_admission_controllers.dart';
import '../../application/group_management_controllers.dart';
import '../../data/models/group_models.dart';
import '../widgets/group_widgets.dart';

String _failureText(Object? failure) =>
    failure == null ? '' : 'Unable to complete this action. Please try again.';

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
      appBar: AppBar(title: const Text('Group Invitations')),
      body: ValueListenableBuilder<GroupAsyncState<List<GroupInvitationResponse>>>(
        valueListenable: widget.controller,
        builder: (context, state, _) {
          if (state.loading && state.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = state.data ?? const [];
          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mail_outline, size: 56, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'No pending group invitations',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final inv = items[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.groups, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Group ID: ${inv.groupId}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Invited by: ${inv.inviterUserId}'),
                      Text(
                        'Sent: ${inv.createdAt.toLocal().toString().split('.').first}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
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
                            child: const Text('Decline'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
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
                            child: const Text('Accept'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
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
  @override
  void initState() {
    super.initState();
    widget.controller.load(widget.groupId);
  }

  void _showCreateDialog() {
    final maxUsesController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Invite Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: maxUsesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Max Uses (optional)',
                hintText: 'Leave empty for unlimited',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final max = int.tryParse(maxUsesController.text.trim());
              Navigator.of(ctx).pop();
              await widget.controller.create(
                widget.groupId,
                CreateInviteLinkRequest(maxUses: max),
              );
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite Links'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateDialog,
          ),
        ],
      ),
      body: ValueListenableBuilder<GroupAsyncState<List<InviteLinkResponse>>>(
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
                  const Icon(Icons.link_off, size: 56, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('No invite links yet'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _showCreateDialog,
                    child: const Text('Generate Invite Link'),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final link = items[i];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.link, color: AppColors.primary),
                  title: SelectableText(
                    link.inviteCode,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  subtitle: Text(
                    'Uses: ${link.usesCount}${link.maxUses != null ? '/${link.maxUses}' : ' (unlimited)'}\n'
                    'Status: ${link.isRevoked ? 'Revoked' : 'Active'}',
                  ),
                  trailing: link.isRevoked
                      ? const Chip(label: Text('Revoked'))
                      : OutlinedButton(
                          onPressed: () => widget.controller.revoke(
                            widget.groupId,
                            link.id,
                          ),
                          child: const Text('Revoke'),
                        ),
                ),
              );
            },
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
      appBar: AppBar(title: const Text('Join Requests')),
      body: ValueListenableBuilder<GroupAsyncState<List<JoinRequestResponse>>>(
        valueListenable: widget.controller,
        builder: (context, state, _) {
          if (state.loading && state.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = state.data ?? const [];
          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_add_disabled, size: 56, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No pending join requests'),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final req = items[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const CircleAvatar(child: Icon(Icons.person)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'User: ${req.requesterUserId}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Requested: ${req.createdAt.toLocal().toString().split('.').first}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () => widget.controller.approve(
                          widget.groupId,
                          req.id,
                        ),
                        tooltip: 'Approve',
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => widget.controller.reject(
                          widget.groupId,
                          req.id,
                        ),
                        tooltip: 'Reject',
                      ),
                    ],
                  ),
                ),
              );
            },
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
      appBar: AppBar(title: const Text('Banned Users')),
      body: ValueListenableBuilder<GroupAsyncState<List<GroupBanResponse>>>(
        valueListenable: widget.controller,
        builder: (context, state, _) {
          if (state.loading && state.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = state.data ?? const [];
          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block, size: 56, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No banned users in this group'),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final ban = items[i];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.block, color: Colors.red),
                  title: Text('User: ${ban.bannedUserId}'),
                  subtitle: Text(
                    'Reason: ${ban.reason ?? 'No reason provided'}\n'
                    'Banned: ${ban.createdAt.toLocal().toString().split('.').first}',
                  ),
                  trailing: OutlinedButton(
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
                    child: const Text('Unban'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
