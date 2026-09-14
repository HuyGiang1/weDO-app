import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../application/group_activity_log_controller.dart';
import '../../data/models/group_models.dart';

class GroupActivityLogScreen extends StatefulWidget {
  final String groupId;
  final GroupActivityLogController controller;
  const GroupActivityLogScreen({
    super.key,
    required this.groupId,
    required this.controller,
  });
  @override
  State<GroupActivityLogScreen> createState() => _GroupActivityLogScreenState();
}

class _GroupActivityLogScreenState extends State<GroupActivityLogScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.load(widget.groupId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      centerTitle: true,
      title: const Text('Activity Log'),
      leading: IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    ),
    body: ValueListenableBuilder<GroupActivityLogState>(
      valueListenable: widget.controller,
      builder: (context, state, _) {
        if (state.loading) return const Center(child: CircularProgressIndicator());
        if (state.failure != null && state.activities.isEmpty) {
          return Center(
            child: OutlinedButton.icon(
              onPressed: () => widget.controller.load(widget.groupId),
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          );
        }
        if (state.activities.isEmpty) {
          return const Center(child: Text('No activity yet'));
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            _ActivityTimeline(activities: state.activities),
            if (state.failure != null)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Unable to load more activity.'),
              ),
            if (state.hasNext)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton(
                  onPressed: state.loadingMore
                      ? null
                      : () => widget.controller.loadMore(widget.groupId),
                  child: state.loadingMore
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Load more'),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _ActivityTimeline extends StatelessWidget {
  final List<GroupActivityLog> activities;
  const _ActivityTimeline({required this.activities});
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(
        top: 0,
        bottom: 24,
        left: 23,
        child: Container(width: 2, color: const Color(0xFFCCC3D8).withValues(alpha: .45)),
      ),
      Column(
        children: [
          for (final activity in activities) _ActivityRow(activity: activity),
        ],
      ),
    ],
  );
}

class _ActivityRow extends StatelessWidget {
  final GroupActivityLog activity;
  const _ActivityRow({required this.activity});
  @override
  Widget build(BuildContext context) {
    final visual = activityVisual(activity.action);
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: visual.color.withValues(alpha: .12),
              shape: BoxShape.circle,
              border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 4),
            ),
            child: Icon(visual.icon, color: visual.color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Color(0x0A7C3AED), blurRadius: 20, offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(visual.message, style: const TextStyle(fontSize: 16, height: 1.5)),
                  const SizedBox(height: 8),
                  Text(
                    formatActivityTimestamp(activity.createdAt),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF4A4455)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ActivityVisual {
  final IconData icon;
  final Color color;
  final String message;
  const ActivityVisual(this.icon, this.color, this.message);
}

ActivityVisual activityVisual(String action) => switch (action) {
  'GROUP_CREATED' => const ActivityVisual(Icons.group_add, AppColors.primary, 'Group created'),
  'GROUP_UPDATED' => const ActivityVisual(Icons.edit, AppColors.primary, 'Group information updated'),
  'GROUP_SETTINGS_UPDATED' => const ActivityVisual(Icons.tune, Color(0xFF006B5F), 'Group settings updated'),
  'GROUP_ADMIN_PROMOTED' => const ActivityVisual(Icons.admin_panel_settings, AppColors.primary, 'A member was promoted to Admin'),
  'GROUP_ADMIN_DEMOTED' => const ActivityVisual(Icons.person_outline, Color(0xFF006B5F), 'An Admin was changed to Member'),
  'GROUP_MEMBER_KICKED' => const ActivityVisual(Icons.person_remove, Color(0xFF7D3D00), 'A member was removed from the group'),
  'GROUP_MEMBER_LEFT' => const ActivityVisual(Icons.logout, Color(0xFF7D3D00), 'A member left the group'),
  'GROUP_OWNERSHIP_TRANSFERRED' => const ActivityVisual(Icons.swap_horiz, AppColors.primary, 'Group ownership was transferred'),
  _ => const ActivityVisual(Icons.info_outline, Color(0xFF4A4455), 'Group activity updated'),
};

String formatActivityTimestamp(DateTime value, {DateTime? now}) {
  final current = (now ?? DateTime.now()).toLocal();
  final time = value.toLocal();
  final difference = current.difference(time);
  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inHours < 24 && current.day == time.day) {
    return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
  }
  final clock = _clock(time);
  if (difference.inDays == 1 ||
      (current.day - time.day == 1 && current.month == time.month && current.year == time.year)) {
    return 'Yesterday at $clock';
  }
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[time.month - 1]} ${time.day}, ${time.year}';
}

String _clock(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
}
