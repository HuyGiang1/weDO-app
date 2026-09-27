DateTime combineTaskDueAt(DateTime date, Duration timeOfDay) => DateTime(
  date.year,
  date.month,
  date.day,
  timeOfDay.inHours,
  timeOfDay.inMinutes.remainder(60),
);

bool isFutureTaskDueAt(DateTime dueAt, {DateTime? now}) =>
    dueAt.isAfter(now ?? DateTime.now());
