import 'dart:math';

import 'secure_key_value_store.dart';

/// Durable storage for the authenticated session only.
class SecureStorageService {
  static const String accessTokenKey = 'auth.access_token';
  static const String refreshTokenKey = 'auth.refresh_token';
  static const String notificationDeviceIdKey = 'notification.device_id';
  static const String notificationPermissionRequestedKey =
      'notification.permission_requested';

  final SecureKeyValueStore _store;

  SecureStorageService({SecureKeyValueStore? store})
    : _store = store ?? FlutterSecureKeyValueStore();

  Future<String?> readAccessToken() => _store.read(accessTokenKey);

  Future<String?> readRefreshToken() => _store.read(refreshTokenKey);

  Future<String> getOrCreateNotificationDeviceId() async {
    final String? existing = await _store.read(notificationDeviceIdKey);
    if (existing != null && existing.trim().isNotEmpty) return existing;

    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final String hex = bytes
        .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    final String id =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    await _store.write(key: notificationDeviceIdKey, value: id);
    return id;
  }

  Future<bool> hasRequestedNotificationPermission() async =>
      await _store.read(notificationPermissionRequestedKey) == 'true';

  Future<void> markNotificationPermissionRequested() =>
      _store.write(key: notificationPermissionRequestedKey, value: 'true');

  /// Writes both credentials, clearing both keys if either write fails so a
  /// known partial session is not retained.
  Future<void> writeSession({
    required String accessToken,
    required String refreshToken,
  }) async {
    try {
      await _store.write(key: accessTokenKey, value: accessToken);
      await _store.write(key: refreshTokenKey, value: refreshToken);
    } catch (_) {
      await _clearSessionBestEffort();
      rethrow;
    }
  }

  Future<void> clearSession() async {
    await _store.delete(accessTokenKey);
    await _store.delete(refreshTokenKey);
  }

  Future<void> _clearSessionBestEffort() async {
    try {
      await clearSession();
    } catch (_) {
      // Preserve the original write error; a later explicit clear can retry.
    }
  }
}
