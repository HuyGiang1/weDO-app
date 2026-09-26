/// Centralized date and time formatting utilities for weDO.
/// All user-facing timestamps are formatted in local time using Vietnamese conventions
/// (dd-MM-yyyy, HH:mm) while keeping wire communication strictly ISO-8601 UTC.
class AppDateTimeFormatter {
  const AppDateTimeFormatter._();

  static String _pad2(int n) => n.toString().padLeft(2, '0');

  /// Formats date as `dd-MM-yyyy` in local time.
  static String formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${_pad2(local.day)}-${_pad2(local.month)}-${local.year}';
  }

  /// Formats time as `HH:mm` (24h) in local time.
  static String formatTime(DateTime dt) {
    final local = dt.toLocal();
    return '${_pad2(local.hour)}:${_pad2(local.minute)}';
  }

  /// Formats full date-time as `HH:mm, dd-MM-yyyy`.
  static String formatDateTime(DateTime dt) {
    return '${formatTime(dt)}, ${formatDate(dt)}';
  }

  /// Vietnamese relative time formatting for logs and activity feeds.
  static String formatRelativeTime(DateTime dt, {DateTime? clockNow}) {
    final now = (clockNow ?? DateTime.now()).toLocal();
    final local = dt.toLocal();
    final difference = now.difference(local);

    if (difference.isNegative || difference.inSeconds < 60) {
      return 'Vừa xong';
    }
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} phút trước';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours} giờ trước';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays} ngày trước';
    }
    return formatDate(local);
  }

  /// Human-friendly activity time range string in Vietnamese.
  /// If [startAt] is null, explicitly returns "Chưa xếp lịch" (or [unscheduledLabel]).
  /// Same-day format: `dd-MM-yyyy • HH:mm - HH:mm`
  /// Multi-day format: `dd-MM-yyyy HH:mm → dd-MM-yyyy HH:mm`
  static String formatActivitySchedule({
    DateTime? startAt,
    DateTime? endAt,
    String unscheduledLabel = 'Chưa xếp lịch',
  }) {
    if (startAt == null) {
      return unscheduledLabel;
    }
    final localStart = startAt.toLocal();
    if (endAt == null) {
      return '${formatDate(localStart)} • ${formatTime(localStart)}';
    }
    final localEnd = endAt.toLocal();
    final sameDay = localStart.year == localEnd.year &&
        localStart.month == localEnd.month &&
        localStart.day == localEnd.day;

    if (sameDay) {
      return '${formatDate(localStart)} • ${formatTime(localStart)} - ${formatTime(localEnd)}';
    }
    return '${formatDate(localStart)} ${formatTime(localStart)} → ${formatDate(localEnd)} ${formatTime(localEnd)}';
  }
}
