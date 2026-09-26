import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/date_time_formatter.dart';
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
      title: const Text('Nhật ký hoạt động'),
      leading: IconButton(
        tooltip: 'Quay lại',
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
              label: const Text('Thử lại'),
            ),
          );
        }
        if (state.activities.isEmpty) {
          return const Center(child: Text('Chưa có hoạt động nào'));
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            _ActivityTimeline(activities: state.activities),
            if (state.failure != null)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Không thể tải thêm hoạt động.'),
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
                      : const Text('Tải thêm'),
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
  'GROUP_CREATED' => const ActivityVisual(Icons.group_add, AppColors.primary, 'Nhóm được tạo'),
  'GROUP_UPDATED' => const ActivityVisual(Icons.edit, AppColors.primary, 'Thông tin nhóm đã được cập nhật'),
  'GROUP_SETTINGS_UPDATED' => const ActivityVisual(Icons.tune, Color(0xFF006B5F), 'Cài đặt nhóm đã được cập nhật'),
  'GROUP_ADMIN_PROMOTED' => const ActivityVisual(Icons.admin_panel_settings, AppColors.primary, 'Một thành viên đã được nâng làm Quản trị viên'),
  'GROUP_ADMIN_DEMOTED' => const ActivityVisual(Icons.person_outline, Color(0xFF006B5F), 'Một Quản trị viên đã chuyển thành Thành viên'),
  'GROUP_MEMBER_KICKED' => const ActivityVisual(Icons.person_remove, Color(0xFF7D3D00), 'Một thành viên đã bị xóa khỏi nhóm'),
  'GROUP_MEMBER_LEFT' => const ActivityVisual(Icons.logout, Color(0xFF7D3D00), 'Một thành viên đã rời nhóm'),
  'GROUP_OWNERSHIP_TRANSFERRED' => const ActivityVisual(Icons.swap_horiz, AppColors.primary, 'Quyền sở hữu nhóm đã được chuyển giao'),
  'ACTIVITY_CREATED' => const ActivityVisual(Icons.add_circle_outline, AppColors.primary, 'Hoạt động mới đã được tạo'),
  'ACTIVITY_CONFIRMED' => const ActivityVisual(Icons.check_circle_outline, Color(0xFF006B5F), 'Hoạt động đã được xác nhận'),
  'ACTIVITY_UPDATED' => const ActivityVisual(Icons.edit_calendar, AppColors.primary, 'Hoạt động đã được cập nhật'),
  'ACTIVITY_CANCELLED' => const ActivityVisual(Icons.cancel_outlined, Color(0xFFBA1A1A), 'Hoạt động đã bị hủy'),
  'ACTIVITY_COMPLETED' => const ActivityVisual(Icons.done_all, Color(0xFF006B5F), 'Hoạt động đã hoàn thành'),
  _ => const ActivityVisual(Icons.info_outline, Color(0xFF4A4455), 'Hoạt động nhóm được cập nhật'),
};

String formatActivityTimestamp(DateTime value, {DateTime? now}) {
  return AppDateTimeFormatter.formatRelativeTime(value, clockNow: now);
}
