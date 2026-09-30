import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import 'calendar_models.dart';

class CalendarApi {
  final Dio dio;
  CalendarApi(this.dio);

  Future<List<CalendarActivity>> activities({
    required DateTime from,
    required DateTime to,
    String? rsvp,
    String? groupId,
    String? status,
  }) async {
    try {
      final response = await dio.get(
        '/api/v1/calendar/activities',
        queryParameters: {
          'from': offsetDateTimeQuery(from),
          'to': offsetDateTimeQuery(to),
          ...?(rsvp == null ? null : <String, String>{'rsvp': rsvp}),
          ...?(groupId == null ? null : <String, String>{'groupId': groupId}),
          ...?(status == null ? null : <String, String>{'status': status}),
        },
      );
      if (response.data is! List) {
        throw const FormatException('Expected JSON list');
      }
      return (response.data as List).map((item) {
        if (item is! Map) {
          throw const FormatException('Expected JSON object');
        }
        return CalendarActivity.fromJson(Map<String, dynamic>.from(item));
      }).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<ActivityReminder> getReminder(String activityId) async {
    try {
      final response = await dio.get(
        '/api/v1/activities/${Uri.encodeComponent(activityId)}/reminder',
      );
      if (response.data is! Map) {
        throw const FormatException('Expected JSON object');
      }
      return ActivityReminder.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<ActivityReminder> updateReminder(
    String activityId, {
    required bool enabled,
    int? offsetMinutes,
  }) async {
    try {
      final response = await dio.put(
        '/api/v1/activities/${Uri.encodeComponent(activityId)}/reminder',
        data: {
          'enabled': enabled,
          ...?(offsetMinutes == null
              ? null
              : <String, int>{'offsetMinutes': offsetMinutes}),
        },
      );
      if (response.data is! Map) {
        throw const FormatException('Expected JSON object');
      }
      return ActivityReminder.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
