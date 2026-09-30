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
          title: Text('Personal reminder'),
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
              'Personal reminder',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              const Text('Reminder settings could not be updated.'),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
            if (reminder != null) ...[
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Remind me'),
                value: reminder.enabled,
                onChanged: reminder.canConfigure && !_saving
                    ? (enabled) => _save(enabled: enabled)
                    : null,
              ),
              if (reminder.canConfigure) ...[
                Row(
                  children: [
                    const Expanded(child: Text('Before activity')),
                    DropdownButton<int>(
                      value: const [5, 15, 30, 60, 1440].contains(_offset)
                          ? _offset
                          : 15,
                      items: const [5, 15, 30, 60, 1440]
                          .map(
                            (minutes) => DropdownMenuItem(
                              value: minutes,
                              child: Text(
                                minutes == 1440 ? '1 day' : '$minutes min',
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
                  'Reminder time: ${MaterialLocalizations.of(context).formatFullDate(reminder.remindAt!.toLocal())} ${TimeOfDay.fromDateTime(reminder.remindAt!.toLocal()).format(context)}',
                ),
              if (_saving) const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  String _reason(String? reason) => switch (reason) {
    'GROUP_ARCHIVED' => 'Reminders are unavailable for archived groups.',
    'ACTIVITY_TERMINAL' =>
      'Reminders are unavailable for completed or cancelled activities.',
    'ACTIVITY_IN_PROGRESS' =>
      'Reminders are unavailable after an activity starts.',
    'ACTIVITY_UNSCHEDULED' =>
      'Add a date and time before configuring a reminder.',
    'ACTIVITY_ALREADY_STARTED' => 'This activity has already started.',
    _ => 'Reminder settings are unavailable.',
  };
}
