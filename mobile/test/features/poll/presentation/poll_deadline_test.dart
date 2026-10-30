import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/poll/presentation/poll_deadline.dart';

void main() {
  testWidgets('refreshes once at the nearest future deadline and cancels on dispose', (tester) async {
    final now = DateTime.utc(2030);
    var refreshes = 0;
    final deadline = PollDeadlineRefresh(() => refreshes++, now: () => now);
    deadline.schedule([null, now.subtract(const Duration(seconds: 1)), now.add(const Duration(seconds: 5)), now.add(const Duration(seconds: 10))]);
    await tester.pump(const Duration(seconds: 4));
    expect(refreshes, 0);
    await tester.pump(const Duration(seconds: 2));
    expect(refreshes, 1);
    await tester.pump(const Duration(seconds: 10));
    expect(refreshes, 1); // Not a periodic timer.
    deadline.schedule([now.add(const Duration(seconds: 5))]);
    deadline.dispose();
    await tester.pump(const Duration(seconds: 10));
    expect(refreshes, 1);
  });
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
