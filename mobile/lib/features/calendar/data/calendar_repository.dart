import 'calendar_api.dart';
import 'calendar_models.dart';

class CalendarRepository {
  final CalendarApi api;
  CalendarRepository(this.api);

  Future<List<CalendarActivity>> activities({
    required DateTime from,
    required DateTime to,
    String? rsvp,
    String? groupId,
    String? status,
  }) => api.activities(
    from: from,
    to: to,
    rsvp: rsvp,
    groupId: groupId,
    status: status,
  );

  Future<ActivityReminder> getReminder(String id) => api.getReminder(id);
  Future<ActivityReminder> updateReminder(
    String id, {
    required bool enabled,
    int? offsetMinutes,
  }) => api.updateReminder(id, enabled: enabled, offsetMinutes: offsetMinutes);
}
