/// In-memory access-token source for authenticated network requests.
///
/// Persistence belongs exclusively to SecureStorageService. This holder never
/// stores refresh or onboarding credentials.
class AccessTokenHolder {
  String? _accessToken;

  String? get currentAccessToken => _accessToken;

  void setAccessToken(String accessToken) {
    _accessToken = accessToken;
  }

  void clearAccessToken() {
    _accessToken = null;
  }
}
