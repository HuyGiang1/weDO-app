import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_config.dart';

void main() {
  group('ApiConfig', () {
    test('accepts an injected absolute backend URL', () {
      final config = ApiConfig(baseUrl: 'https://api.example.test/v1');

      expect(config.baseUrl, 'https://api.example.test/v1');
    });

    test('normalizes trailing slashes', () {
      final config = ApiConfig(baseUrl: 'https://api.example.test/v1///');

      expect(config.baseUrl, 'https://api.example.test/v1');
    });

    test('rejects blank configuration', () {
      expect(() => ApiConfig(baseUrl: '   '), throwsArgumentError);
    });

    test('rejects a missing production dart-define', () {
      expect(() => ApiConfig(), throwsArgumentError);
    });
  });
}
