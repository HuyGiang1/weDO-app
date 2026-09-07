import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';

void main() {
  testWidgets('WeDoApp mounts and displays initial WelcomeScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const WeDoApp());

    expect(find.text('WeDo'), findsOneWidget);
    expect(find.text('Squad up.'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('Welcome Login reaches LoginScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const WeDoApp());

    final loginButton = find.text('Login');
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Welcome Create Account reaches RegisterScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const WeDoApp());

    final createAccountButton = find.text('Create Account');
    await tester.ensureVisible(createAccountButton);
    await tester.tap(createAccountButton);
    await tester.pumpAndSettle();

    expect(find.text('Join WeDo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Register Login reaches LoginScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const WeDoApp());

    final createAccountButton = find.text('Create Account');
    await tester.ensureVisible(createAccountButton);
    await tester.tap(createAccountButton);
    await tester.pumpAndSettle();
    expect(find.text('Join WeDo'), findsOneWidget);

    final loginButton = find.text('Login');
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Login Forgot Password reaches ForgotPasswordScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const WeDoApp());

    final loginButton = find.text('Login');
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    final forgotPassword = find.text('Forgot Password?');
    await tester.ensureVisible(forgotPassword);
    await tester.tap(forgotPassword);
    await tester.pumpAndSettle();

    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Login Create Account reaches RegisterScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const WeDoApp());

    final loginButton = find.text('Login');
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    final createAccountButton = find.text('Create Account');
    await tester.ensureVisible(createAccountButton);
    await tester.tap(createAccountButton);
    await tester.pumpAndSettle();

    expect(find.text('Join WeDo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
