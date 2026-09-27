import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/poll/presentation/poll_deadline.dart';

void main() {
  test('combines a selected date and time as one local deadline', () {
    final deadline = combinePollDeadline(
      DateTime(2026, 9, 26),
      const Duration(hours: 21, minutes: 30),
    );

    expect(deadline, DateTime(2026, 9, 26, 21, 30));
  });

  test('allows a same-day future deadline', () {
    expect(
      isFuturePollDeadline(
        DateTime(2026, 9, 26, 21),
        now: DateTime(2026, 9, 26, 16),
      ),
      isTrue,
    );
  });

  test('rejects a same-day past deadline', () {
    expect(
      isFuturePollDeadline(
        DateTime(2026, 9, 26, 15),
        now: DateTime(2026, 9, 26, 16),
      ),
      isFalse,
    );
  });
}
