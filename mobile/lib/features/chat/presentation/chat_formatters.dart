String chatTime(DateTime value) {
  final local = value.toLocal();
  return '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

String chatListTime(DateTime value) {
  final local = value.toLocal();
  return '${_twoDigits(local.day)}/${_twoDigits(local.month)} ${chatTime(local)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
