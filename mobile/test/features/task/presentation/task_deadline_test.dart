import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/task/presentation/task_deadline.dart';

void main() {
  test('combines a selected date and time as one local due time', () {
    expect(
      combineTaskDueAt(
        DateTime(2026, 9, 26),
        const Duration(hours: 21, minutes: 30),
      ),
      DateTime(2026, 9, 26, 21, 30),
    );
  });

  test('allows a same-day future due time', () {
    expect(
      isFutureTaskDueAt(
        DateTime(2026, 9, 26, 21),
        now: DateTime(2026, 9, 26, 16),
      ),
      isTrue,
    );
  });

  test('rejects a same-day past due time', () {
    expect(
      isFutureTaskDueAt(
        DateTime(2026, 9, 26, 15),
        now: DateTime(2026, 9, 26, 16),
      ),
      isFalse,
    );
  });
}
