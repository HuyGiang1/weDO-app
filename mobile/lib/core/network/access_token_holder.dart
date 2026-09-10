/// In-memory access-token source for authenticated network requests.
///
/// Persistence belongs exclusively to SecureStorageService. This holder never
/// stores refresh or onboarding credentials.
class AccessTokenHolder {
  String? _accessToken;
  int _revision = 0;

  String? get currentAccessToken => _accessToken;
  int get revision => _revision;

  void setAccessToken(String accessToken) {
    _accessToken = accessToken;
    _revision++;
  }

  void clearAccessToken() {
    _accessToken = null;
    _revision++;
  }
}
