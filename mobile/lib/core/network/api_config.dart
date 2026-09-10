/// Backend configuration supplied by application composition.
///
/// Production reads [environmentVariable] from a compile-time `--dart-define`.
/// Tests and other composition roots can inject a URL directly.
class ApiConfig {
  static const String environmentVariable = 'WEDO_API_BASE_URL';

  final String baseUrl;

  factory ApiConfig({String? baseUrl}) {
    final configuredUrl =
        baseUrl ?? const String.fromEnvironment(environmentVariable);
    return ApiConfig._(configuredUrl);
  }

  ApiConfig._(String rawBaseUrl) : baseUrl = _normalizeBaseUrl(rawBaseUrl);

  static String _normalizeBaseUrl(String rawBaseUrl) {
    final candidate = rawBaseUrl.trim();
    if (candidate.isEmpty) {
      throw ArgumentError.value(
        rawBaseUrl,
        environmentVariable,
        'Provide a non-empty backend URL with '
        '--dart-define=$environmentVariable=<url>.',
      );
    }

    final uri = Uri.tryParse(candidate);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ArgumentError.value(
        rawBaseUrl,
        environmentVariable,
        'Must be an absolute http(s) URL without query or fragment.',
      );
    }

    return candidate.replaceFirst(RegExp(r'/+$'), '');
  }
}
