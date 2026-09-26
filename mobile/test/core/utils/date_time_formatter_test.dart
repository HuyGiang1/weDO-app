import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/utils/date_time_formatter.dart';

void main() {
  group('AppDateTimeFormatter', () {
    test('formatDate formats dd-MM-yyyy in local time', () {
      final dt = DateTime(2026, 3, 31, 14, 0);
      expect(AppDateTimeFormatter.formatDate(dt), '31-03-2026');
    });

    test('formatTime formats HH:mm in local time', () {
      final dt = DateTime(2026, 3, 31, 9, 5);
      expect(AppDateTimeFormatter.formatTime(dt), '09:05');
    });

    test('formatActivitySchedule unscheduled returns default label', () {
      expect(
        AppDateTimeFormatter.formatActivitySchedule(startAt: null, endAt: null),
        'Chưa xếp lịch',
      );
    });

    test('formatActivitySchedule start only', () {
      final start = DateTime(2026, 3, 31, 14, 0);
      expect(
        AppDateTimeFormatter.formatActivitySchedule(startAt: start),
        '31-03-2026 • 14:00',
      );
    });

    test('formatActivitySchedule same-day event: 31-03-2026 • 14:00 - 17:00', () {
      final start = DateTime(2026, 3, 31, 14, 0);
      final end = DateTime(2026, 3, 31, 17, 0);
      expect(
        AppDateTimeFormatter.formatActivitySchedule(startAt: start, endAt: end),
        '31-03-2026 • 14:00 - 17:00',
      );
    });

    test('formatActivitySchedule multi-day event: 31-03-2026 14:00 → 02-04-2026 10:00', () {
      final start = DateTime(2026, 3, 31, 14, 0);
      final end = DateTime(2026, 4, 2, 10, 0);
      expect(
        AppDateTimeFormatter.formatActivitySchedule(startAt: start, endAt: end),
        '31-03-2026 14:00 → 02-04-2026 10:00',
      );
    });
  });
}
