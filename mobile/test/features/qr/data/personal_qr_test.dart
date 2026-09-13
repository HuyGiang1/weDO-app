import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/qr/data/personal_qr.dart';

void main() {
  test('parses only the backend-provided deepLink field', () {
    const deepLink = 'wedo://user/550e8400-e29b-41d4-a716-446655440000';
    expect(PersonalQr.fromJson({'deepLink': deepLink}).deepLink, deepLink);
  });

  test('rejects missing or invalid deepLink', () {
    expect(() => PersonalQr.fromJson({}), throwsFormatException);
    expect(() => PersonalQr.fromJson({'deepLink': ''}), throwsFormatException);
  });
}
