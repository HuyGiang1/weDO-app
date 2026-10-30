import 'package:flutter/material.dart';
import '../../../core/realtime/realtime_binding.dart';
import '../../../core/realtime/reliable_read.dart';

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

class _ActivityReminderPanelState extends State<ActivityReminderPanel>
    with RealtimeBinding<ActivityReminderPanel> {
  final _read = ReliableRead<ActivityReminder>();
  bool _saving = false, _offsetDirty = false;
  int _offset = 15, _accessEpoch = 0;

  @override
  String get realtimeScope => 'activity:${widget.activityId}';
  @override
  String get realtimePrefix => 'ACTIVITY_';
  @override
  String get realtimeAggregateId => widget.activityId;
  @override
  bool get realtimeReadNeedsRecovery => _read.failure?.retainData == true;
  @override
  Future<void> reloadRealtime() => _load();
  @override
  void onRealtimeAccessLost() {
    _accessEpoch++;
    _saving = false;
    _offsetDirty = false;
    _read.denyAccess();
  }

  @override
  void initState() {
    super.initState();
    _read.addListener(_changed);
    _load();
  }

  void _changed() { if (mounted) setState(() {}); }

  Future<void> _load() => _read.load(
    () => widget.repository.getReminder(widget.activityId),
    onData: (value) {
      if (!_offsetDirty) _offset = value.offsetMinutes ?? 15;
    },
  );

  Future<void> _save({required bool enabled, int? offset}) async {
    if (_saving || _read.failure != null || _read.value.data?.canConfigure != true) return;
    final access = _accessEpoch, generation = _read.generation;
    setState(() => _saving = true);
    try {
      final result = await widget.repository.updateReminder(
        widget.activityId, enabled: enabled, offsetMinutes: offset ?? _offset);
      if (!mounted || access != _accessEpoch) return;
      _offsetDirty = false;
      if (_read.isCurrent(generation)) {
        _offset = result.offsetMinutes ?? _offset;
        _read.accept(result);
      } else {
        await _load();
      }
    } catch (error, stack) {
      if (!mounted || access != _accessEpoch) return;
      if (_read.isCurrent(generation)) {
        await _read.load(() => Future<ActivityReminder>.error(error, stack));
      } else if (ReadFailure.fromError(error) == null) {
        FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
      }
    } finally {
      if (mounted && access == _accessEpoch) setState(() => _saving = false);
    }
  }

  @override
  void didUpdateWidget(covariant ActivityReminderPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activityId != widget.activityId || oldWidget.repository != widget.repository) {
      _accessEpoch++;
      _saving = false;
      _offsetDirty = false;
      _read.reset();
      refreshRealtimeBindings();
      _load();
    }
  }

  @override
  void dispose() {
    _accessEpoch++;
    _read.removeListener(_changed);
    _read.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_read.value.connectionState == ConnectionState.waiting && !_read.value.hasData) {
      return const Card(
        child: ListTile(
          leading: CircularProgressIndicator(),
          title: Text('Nhắc nhở cá nhân'),
        ),
      );
    }
    final reminder = _read.value.data;
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 0.8),
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
            if (_read.failure != null) ...[
              const SizedBox(height: 8),
              const Text('Không thể cập nhật nhắc nhở.'),
              TextButton(onPressed: _load, child: const Text('Thử lại')),
            ],
            if (reminder != null) ...[
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Nhắc tôi'),
                value: reminder.enabled,
                onChanged: reminder.canConfigure && !_saving && _read.failure == null
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
                      onChanged: _saving || _read.failure != null
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() { _offset = value; _offsetDirty = true; });
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
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
