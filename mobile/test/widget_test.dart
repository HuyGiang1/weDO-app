import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';

void main() {
  testWidgets('WeDoApp mounts and displays initial WelcomeScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const WeDoApp());

    expect(find.text('WeDo'), findsOneWidget);
    expect(find.text('Squad up.'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
