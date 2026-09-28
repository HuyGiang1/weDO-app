String chatTime(DateTime value) {
  final local = value.toLocal();
  return '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

String chatListTime(DateTime value) {
  final local = value.toLocal();
  return '${_twoDigits(local.day)}/${_twoDigits(local.month)} ${chatTime(local)}';
}

bool isSameLocalDate(DateTime a, DateTime b) {
  final localA = a.toLocal();
  final localB = b.toLocal();
  return localA.year == localB.year &&
      localA.month == localB.month &&
      localA.day == localB.day;
}

bool shouldShowChatTimeSeparator(
  DateTime? previousCreatedAt,
  DateTime currentCreatedAt,
) {
  if (previousCreatedAt == null) return true;
  if (!isSameLocalDate(previousCreatedAt, currentCreatedAt)) return true;
  final gapMinutes = currentCreatedAt
      .toLocal()
      .difference(previousCreatedAt.toLocal())
      .inMinutes
      .abs();
  return gapMinutes >= 30;
}

String chatSeparatorLabel(DateTime value, {DateTime? now}) {
  final local = value.toLocal();
  final localNow = (now ?? DateTime.now()).toLocal();
  final timeText = chatTime(local);
  if (isSameLocalDate(local, localNow)) {
    return timeText;
  }
  final todayStart = DateTime(localNow.year, localNow.month, localNow.day);
  final valueStart = DateTime(local.year, local.month, local.day);
  if (todayStart.difference(valueStart).inDays == 1) {
    return 'Hôm qua $timeText';
  }
  return '${_twoDigits(local.day)}/${_twoDigits(local.month)}/${local.year} $timeText';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
