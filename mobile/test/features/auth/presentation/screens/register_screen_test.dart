import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/ui/widgets/app_password_field.dart';
import 'package:mobile/core/ui/widgets/app_text_field.dart';
import 'package:mobile/features/auth/presentation/screens/register_screen.dart';

void main() {
  Widget buildSubject({
    Future<void> Function(String email, String password)? onSubmit,
    VoidCallback? onLoginPressed,
    VoidCallback? onRegistrationSuccess,
  }) {
    return MaterialApp(
      home: RegisterScreen(
        onSubmit: onSubmit,
        onLoginPressed: onLoginPressed ?? () {},
        onRegistrationSuccess: onRegistrationSuccess,
      ),
    );
  }

  group('RegisterScreen Widget Tests', () {
    testWidgets('renders title, subtitle, form fields, button, and footer', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      // Header
      expect(find.text('Join WeDo'), findsOneWidget);
      expect(find.text('Connect with your community.'), findsOneWidget);

      // Logo asset
      expect(find.byType(Image), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<AssetImage>());
      expect(
        (image.image as AssetImage).assetName,
        equals('assets/images/wedo_logo.png'),
      );

      // Form labels
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);

      // Action button & footer
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Already have an account? '), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('toggles password visibility', (tester) async {
      await tester.pumpWidget(buildSubject());

      // Password field obscure text initially true
      final passwordFieldFinder = find.widgetWithText(
        AppPasswordField,
        'Password',
      );
      expect(passwordFieldFinder, findsOneWidget);

      final textFieldInsidePassword = find.descendant(
        of: passwordFieldFinder,
        matching: find.byType(TextField),
      );
      TextField textField = tester.widget<TextField>(textFieldInsidePassword);
      expect(textField.obscureText, isTrue);

      // Tap visibility toggle inside Password field
      final toggleFinder = find.descendant(
        of: passwordFieldFinder,
        matching: find.byType(IconButton),
      );
      await tester.tap(toggleFinder);
      await tester.pump();

      textField = tester.widget<TextField>(textFieldInsidePassword);
      expect(textField.obscureText, isFalse);

      // Tap again to hide
      await tester.tap(toggleFinder);
      await tester.pump();

      textField = tester.widget<TextField>(textFieldInsidePassword);
      expect(textField.obscureText, isTrue);
    });

    testWidgets('validates empty fields on submit', (tester) async {
      await tester.pumpWidget(buildSubject());

      final buttonFinder = find.text('Create Account');
      await tester.ensureVisible(buttonFinder);
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
      expect(find.text('Please confirm your password'), findsOneWidget);
    });

    testWidgets(
      'validates email format, password length, and password confirmation',
      (tester) async {
        await tester.pumpWidget(buildSubject());

        final emailInput = find.descendant(
          of: find.widgetWithText(AppTextField, 'Email'),
          matching: find.byType(TextField),
        );
        final passwordInput = find.descendant(
          of: find.widgetWithText(AppPasswordField, 'Password'),
          matching: find.byType(TextField),
        );
        final confirmPasswordInput = find.descendant(
          of: find.widgetWithText(AppPasswordField, 'Confirm Password'),
          matching: find.byType(TextField),
        );

        // 1. Invalid email & too short password
        await tester.enterText(emailInput, 'invalid-email');
        await tester.enterText(passwordInput, 'short');
        await tester.enterText(confirmPasswordInput, 'short');

        final buttonFinder = find.text('Create Account');
        await tester.ensureVisible(buttonFinder);
        await tester.tap(buttonFinder);
        await tester.pumpAndSettle();

        expect(find.text('Please enter a valid email address'), findsOneWidget);
        expect(
          find.text('Password must be at least 8 characters'),
          findsOneWidget,
        );

        // 2. Valid email, valid password, but mismatched confirmation
        await tester.enterText(emailInput, 'user@wedo.social');
        await tester.enterText(passwordInput, 'validPassword123');
        await tester.enterText(confirmPasswordInput, 'differentPassword123');

        await tester.tap(buttonFinder);
        await tester.pumpAndSettle();

        expect(find.text('Please enter a valid email address'), findsNothing);
        expect(
          find.text('Password must be at least 8 characters'),
          findsNothing,
        );
        expect(find.text('Passwords do not match'), findsOneWidget);
      },
    );

    testWidgets('normalizes email and preserves raw password when valid', (
      tester,
    ) async {
      String? submittedEmail;
      String? submittedPassword;
      var successCalled = false;

      await tester.pumpWidget(
        buildSubject(
          onSubmit: (email, password) async {
            submittedEmail = email;
            submittedPassword = password;
          },
          onRegistrationSuccess: () {
            successCalled = true;
          },
        ),
      );

      final emailInput = find.descendant(
        of: find.widgetWithText(AppTextField, 'Email'),
        matching: find.byType(TextField),
      );
      final passwordInput = find.descendant(
        of: find.widgetWithText(AppPasswordField, 'Password'),
        matching: find.byType(TextField),
      );
      final confirmPasswordInput = find.descendant(
        of: find.widgetWithText(AppPasswordField, 'Confirm Password'),
        matching: find.byType(TextField),
      );

      await tester.enterText(emailInput, '  Test.User@Example.COM  ');
      await tester.enterText(passwordInput, 'secretPass123');
      await tester.enterText(confirmPasswordInput, 'secretPass123');

      final buttonFinder = find.text('Create Account');
      await tester.ensureVisible(buttonFinder);
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(submittedEmail, equals('test.user@example.com'));
      expect(submittedPassword, equals('secretPass123'));
      expect(successCalled, isTrue);
    });

    testWidgets('does not call onRegistrationSuccess if onSubmit is null', (
      tester,
    ) async {
      var successCalled = false;

      await tester.pumpWidget(
        buildSubject(
          onSubmit: null,
          onRegistrationSuccess: () {
            successCalled = true;
          },
        ),
      );

      final emailInput = find.descendant(
        of: find.widgetWithText(AppTextField, 'Email'),
        matching: find.byType(TextField),
      );
      final passwordInput = find.descendant(
        of: find.widgetWithText(AppPasswordField, 'Password'),
        matching: find.byType(TextField),
      );
      final confirmPasswordInput = find.descendant(
        of: find.widgetWithText(AppPasswordField, 'Confirm Password'),
        matching: find.byType(TextField),
      );

      await tester.enterText(emailInput, 'user@wedo.social');
      await tester.enterText(passwordInput, 'password123');
      await tester.enterText(confirmPasswordInput, 'password123');

      final buttonFinder = find.text('Create Account');
      await tester.ensureVisible(buttonFinder);
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(successCalled, isFalse);
    });

    testWidgets('loading state prevents double submission', (tester) async {
      final completer = Completer<void>();
      var callCount = 0;

      await tester.pumpWidget(
        buildSubject(
          onSubmit: (email, password) async {
            callCount++;
            await completer.future;
          },
        ),
      );

      final emailInput = find.descendant(
        of: find.widgetWithText(AppTextField, 'Email'),
        matching: find.byType(TextField),
      );
      final passwordInput = find.descendant(
        of: find.widgetWithText(AppPasswordField, 'Password'),
        matching: find.byType(TextField),
      );
      final confirmPasswordInput = find.descendant(
        of: find.widgetWithText(AppPasswordField, 'Confirm Password'),
        matching: find.byType(TextField),
      );

      await tester.enterText(emailInput, 'user@wedo.social');
      await tester.enterText(passwordInput, 'password123');
      await tester.enterText(confirmPasswordInput, 'password123');

      final buttonFinder = find.byType(ElevatedButton);
      await tester.ensureVisible(buttonFinder);

      // First tap triggers submit
      await tester.tap(buttonFinder);
      await tester.pump(); // Triggers frame for isLoading = true

      expect(callCount, equals(1));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Second tap while loading should be disabled
      await tester.tap(buttonFinder, warnIfMissed: false);
      await tester.pump();

      expect(callCount, equals(1));

      // Complete async submit
      completer.complete();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('fires onLoginPressed when footer Login is tapped', (
      tester,
    ) async {
      var loginPressed = false;

      await tester.pumpWidget(
        buildSubject(
          onLoginPressed: () {
            loginPressed = true;
          },
        ),
      );

      final loginFinder = find.text('Login');
      await tester.ensureVisible(loginFinder);
      await tester.tap(loginFinder);
      await tester.pump();

      expect(loginPressed, isTrue);
    });

    testWidgets('renders without overflow at normal phone sizes', (
      tester,
    ) async {
      // 390 x 844 (standard modern smartphone)
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildSubject());
      expect(tester.takeException(), isNull);

      // 360 x 640 (compact smartphone)
      tester.view.physicalSize = const Size(360, 640);
      await tester.pumpWidget(buildSubject());
      expect(tester.takeException(), isNull);
    });
  });
}
