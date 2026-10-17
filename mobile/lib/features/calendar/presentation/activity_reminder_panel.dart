import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../data/calendar_models.dart';
import '../data/calendar_repository.dart';

class ActivityReminderPanel extends StatefulWidget {
  final String activityId;
  final CalendarRepository repository;

  const ActivityReminderPanel({
    super.key,
    required this.activityId,
    required this.repository,
  });

  @override
  State<ActivityReminderPanel> createState() => _ActivityReminderPanelState();
}

class _ActivityReminderPanelState extends State<ActivityReminderPanel> {
  ActivityReminder? _reminder;
  bool _loading = true, _saving = false;
  Object? _error;
  int _offset = 15;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await widget.repository.getReminder(widget.activityId);
      if (!mounted) return;
      setState(() {
        _reminder = value;
        _offset = value.offsetMinutes ?? 15;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _save({required bool enabled, int? offset}) async {
    setState(() => _saving = true);
    try {
      final result = await widget.repository.updateReminder(
        widget.activityId,
        enabled: enabled,
        offsetMinutes: offset ?? _offset,
      );
      if (!mounted) return;
      setState(() {
        _reminder = result;
        _offset = result.offsetMinutes ?? _offset;
        _saving = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Card(
        child: ListTile(
          leading: CircularProgressIndicator(),
          title: Text('Nhắc nhở cá nhân'),
        ),
      );
    }
    final reminder = _reminder;
    return Card(
      color: AppColors.surfaceContainerLowest,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.outlineVariant, width: 0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhắc nhở cá nhân',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              const Text('Không thể cập nhật nhắc nhở.'),
              TextButton(onPressed: _load, child: const Text('Thử lại')),
            ],
            if (reminder != null) ...[
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Nhắc tôi'),
                value: reminder.enabled,
                onChanged: reminder.canConfigure && !_saving
                    ? (enabled) => _save(enabled: enabled)
                    : null,
              ),
              if (reminder.canConfigure) ...[
                Row(
                  children: [
                    const Expanded(child: Text('Trước hoạt động')),
                    DropdownButton<int>(
                      value: const [5, 15, 30, 60, 1440].contains(_offset)
                          ? _offset
                          : 15,
                      items: const [5, 15, 30, 60, 1440]
                          .map(
                            (minutes) => DropdownMenuItem(
                              value: minutes,
                              child: Text(
                                minutes == 1440 ? '1 ngày' : '$minutes phút',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() => _offset = value);
                              if (reminder.enabled) {
                                _save(enabled: true, offset: value);
                              }
                            },
                    ),
                  ],
                ),
              ] else
                Text(
                  _reason(reminder.unavailableReason),
                  style: const TextStyle(color: AppColors.onSurfaceVariant),
                ),
              if (reminder.enabled && reminder.remindAt != null)
                Text(
                  'Thời gian nhắc: ${MaterialLocalizations.of(context).formatFullDate(reminder.remindAt!.toLocal())} ${TimeOfDay.fromDateTime(reminder.remindAt!.toLocal()).format(context)}',
                ),
              if (_saving) const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  String _reason(String? reason) => switch (reason) {
    'GROUP_ARCHIVED' => 'Không thể đặt nhắc nhở trong nhóm đã lưu trữ.',
    'ACTIVITY_TERMINAL' =>
      'Không thể đặt nhắc nhở cho hoạt động đã hoàn thành hoặc hủy.',
    'ACTIVITY_IN_PROGRESS' =>
      'Không thể đặt nhắc nhở sau khi hoạt động bắt đầu.',
    'ACTIVITY_UNSCHEDULED' =>
      'Thêm ngày giờ trước khi đặt nhắc nhở.',
    'ACTIVITY_ALREADY_STARTED' => 'Hoạt động đã bắt đầu.',
    _ => 'Cài đặt nhắc nhở chưa khả dụng.',
  };
}
