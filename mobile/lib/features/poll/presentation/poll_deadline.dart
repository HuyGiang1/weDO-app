DateTime combinePollDeadline(DateTime date, Duration timeOfDay) => DateTime(
  date.year,
  date.month,
  date.day,
  timeOfDay.inHours,
  timeOfDay.inMinutes.remainder(60),
);

bool isFuturePollDeadline(DateTime deadline, {DateTime? now}) =>
    deadline.isAfter(now ?? DateTime.now());
