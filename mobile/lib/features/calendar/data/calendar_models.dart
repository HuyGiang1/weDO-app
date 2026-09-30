import '../../activity/data/activity_models.dart';

class CalendarActivity {
  final String id, groupId, groupName, title;
  final ActivityStatus status;
  final DateTime startAt;
  final DateTime? endAt, reminderAt;
  final String? timezone, locationName;
  final int goingCount, waitlistCount;
  final ActivityRsvpStatus callerRsvpStatus;
  final bool reminderEnabled;

  const CalendarActivity({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.title,
    required this.status,
    required this.startAt,
    this.endAt,
    this.timezone,
    this.locationName,
    required this.goingCount,
    required this.waitlistCount,
    required this.callerRsvpStatus,
    required this.reminderEnabled,
    this.reminderAt,
  });

  factory CalendarActivity.fromJson(Map<String, dynamic> json) =>
      CalendarActivity(
        id: _requiredString(json, 'id'),
        groupId: _requiredString(json, 'groupId'),
        groupName: _requiredString(json, 'groupName'),
        title: _requiredString(json, 'title'),
        status: ActivityStatusWire.parse(_requiredString(json, 'status')),
        startAt: DateTime.parse(_requiredString(json, 'startAt')),
        endAt: json['endAt'] == null
            ? null
            : DateTime.parse(_requiredString(json, 'endAt')),
        timezone: json['timezone'] as String?,
        locationName: json['locationName'] as String?,
        goingCount: (json['goingCount'] as num).toInt(),
        waitlistCount: (json['waitlistCount'] as num).toInt(),
        callerRsvpStatus: ActivityRsvpStatusWire.parse(
          _requiredString(json, 'callerRsvpStatus'),
        ),
        reminderEnabled: json['reminderEnabled'] as bool? ?? false,
        reminderAt: json['reminderAt'] == null
            ? null
            : DateTime.parse(_requiredString(json, 'reminderAt')),
      );
}

class ActivityReminder {
  final String activityId;
  final bool configured, enabled, canConfigure;
  final int? offsetMinutes;
  final DateTime? remindAt, sentAt;
  final String? unavailableReason;

  const ActivityReminder({
    required this.activityId,
    required this.configured,
    required this.enabled,
    this.offsetMinutes,
    this.remindAt,
    this.sentAt,
    required this.canConfigure,
    this.unavailableReason,
  });

  factory ActivityReminder.fromJson(Map<String, dynamic> json) =>
      ActivityReminder(
        activityId: _requiredString(json, 'activityId'),
        configured: json['configured'] as bool? ?? false,
        enabled: json['enabled'] as bool? ?? false,
        offsetMinutes: (json['offsetMinutes'] as num?)?.toInt(),
        remindAt: json['remindAt'] == null
            ? null
            : DateTime.parse(_requiredString(json, 'remindAt')),
        sentAt: json['sentAt'] == null
            ? null
            : DateTime.parse(_requiredString(json, 'sentAt')),
        canConfigure: json['canConfigure'] as bool? ?? false,
        unavailableReason: json['unavailableReason'] as String?,
      );
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('Expected string $key');
  return value;
}

String offsetDateTimeQuery(DateTime value) {
  if (value.isUtc) return value.toIso8601String();
  final base = value.toIso8601String();
  final offset = value.timeZoneOffset;
  if (offset == Duration.zero) return '${base}Z';
  final sign = offset.isNegative ? '-' : '+';
  final totalMinutes = offset.inMinutes.abs();
  final hours = (totalMinutes ~/ 60).toString().padLeft(2, '0');
  final minutes = (totalMinutes % 60).toString().padLeft(2, '0');
  return '$base$sign$hours:$minutes';
}
