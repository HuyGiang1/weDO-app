import 'secure_key_value_store.dart';

/// Durable storage for the authenticated session only.
class SecureStorageService {
  static const String accessTokenKey = 'auth.access_token';
  static const String refreshTokenKey = 'auth.refresh_token';

  final SecureKeyValueStore _store;

  SecureStorageService({SecureKeyValueStore? store})
    : _store = store ?? FlutterSecureKeyValueStore();

  Future<String?> readAccessToken() => _store.read(accessTokenKey);

  Future<String?> readRefreshToken() => _store.read(refreshTokenKey);

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
