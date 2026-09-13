import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/qr/data/personal_qr.dart';
import 'package:mobile/features/qr/presentation/screens/personal_qr_screen.dart';

void main() {
  testWidgets('renders the exact backend deepLink and retries failures', (
    tester,
  ) async {
    const deepLink = 'wedo://user/550e8400-e29b-41d4-a716-446655440000';
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PersonalQrScreen(
          loadPersonalQr: () async {
            calls++;
            if (calls == 1) throw StateError('offline');
            return const PersonalQr(deepLink: deepLink);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to load your QR code.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(PersonalQrRenderer), findsOneWidget);
    expect(
      tester
          .widget<PersonalQrRenderer>(find.byType(PersonalQrRenderer))
          .deepLink,
      deepLink,
    );
  });
}
