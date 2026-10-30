import 'dart:async';

/// One authoritative refetch at the nearest known deadline; never periodic polling.
class PollDeadlineRefresh {
  final void Function() refresh;
  final DateTime Function() now;
  Timer? _timer;
  PollDeadlineRefresh(this.refresh, {DateTime Function()? now}) : now = now ?? DateTime.now;
  void schedule(Iterable<DateTime?> deadlines) {
    _timer?.cancel();
    final current = now();
    final future = deadlines.whereType<DateTime>().where((time) => time.isAfter(current)).toList()..sort();
    if (future.isEmpty) return;
    _timer = Timer(future.first.difference(current) + const Duration(milliseconds: 50), refresh);
  }
  void dispose() => _timer?.cancel();
}

DateTime combinePollDeadline(DateTime date, Duration timeOfDay) => DateTime(
  date.year,
  date.month,
  date.day,
  timeOfDay.inHours,
  timeOfDay.inMinutes.remainder(60),
);

bool isFuturePollDeadline(DateTime deadline, {DateTime? now}) =>
    deadline.isAfter(now ?? DateTime.now());
