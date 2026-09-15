import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../application/groups_controller.dart';
import '../../data/models/group_models.dart';
import '../widgets/group_widgets.dart';

class MyGroupsScreen extends StatefulWidget {
  final GroupsController controller;
  final VoidCallback onCreate;
  final ValueChanged<String> onOpenGroup;
  final VoidCallback? onJoinByCode;
  final VoidCallback? onInvitations;

  const MyGroupsScreen({
    super.key,
    required this.controller,
    required this.onCreate,
    required this.onOpenGroup,
    this.onJoinByCode,
    this.onInvitations,
  });
  @override
  State<MyGroupsScreen> createState() => _MyGroupsScreenState();
}

class _MyGroupsScreenState extends State<MyGroupsScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const GroupsBottomNavigation(),
      body: SafeArea(
        child: ValueListenableBuilder<GroupsState>(
          valueListenable: widget.controller,
          builder: (context, state, child) {
            if (state.phase == GroupsPhase.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.phase == GroupsPhase.error) {
              return Center(
                child: OutlinedButton.icon(
                  onPressed: widget.controller.refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thu lai'),
                ),
              );
            }
            final content = <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WeDo',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Nhom cua toi',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Nhung khong gian ban dang cung moi nguoi ket noi.',
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: widget.onCreate,
                    icon: const Icon(Icons.add),
                    label: const Text('Tao nhom'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (widget.onJoinByCode != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onJoinByCode,
                        icon: const Icon(Icons.vpn_key),
                        label: const Text('Join by Code'),
                      ),
                    ),
                  if (widget.onJoinByCode != null && widget.onInvitations != null)
                    const SizedBox(width: 12),
                  if (widget.onInvitations != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onInvitations,
                        icon: const Icon(Icons.mail),
                        label: const Text('Invitations'),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
            ];
            if (state.phase == GroupsPhase.empty) {
              content.add(_GroupsEmpty(onCreate: widget.onCreate));
            }
            if (state.phase == GroupsPhase.data) {
              content.addAll(
                state.groups.map(
                  (group) => _GroupCard(
                    group: group,
                    onTap: () => widget.onOpenGroup(group.id),
                  ),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: widget.controller.refresh,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: content,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final GroupSummary group;
  final VoidCallback onTap;
  const _GroupCard({required this.group, required this.onTap});
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      leading: GroupAvatar(name: group.name),
      title: Row(
        children: [
          Expanded(child: Text(group.name)),
          GroupRoleBadge(role: group.callerRole),
        ],
      ),
      subtitle: Text(groupUpdatedLabel(group.updatedAt)),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}

class _GroupsEmpty extends StatelessWidget {
  final VoidCallback onCreate;
  const _GroupsEmpty({required this.onCreate});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      children: [
        const Icon(Icons.groups_3, size: 56, color: AppColors.primary),
        const Text('Chua co nhom nao'),
        ElevatedButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add),
          label: const Text('Tao nhom'),
        ),
      ],
    ),
  );
}
