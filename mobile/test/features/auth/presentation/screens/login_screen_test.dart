import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/presentation/screens/login_screen.dart';

void main() {
  Widget buildSubject({
    Future<void> Function({required String email, required String password})?
    onLogin,
    VoidCallback? onForgotPassword,
    VoidCallback? onCreateAccount,
  }) => MaterialApp(
    home: LoginScreen(
      onLogin: onLogin,
      onForgotPassword: onForgotPassword,
      onCreateAccount: onCreateAccount ?? () {},
    ),
  );

  Finder emailField() => find.byType(TextFormField).at(0);
  Finder passwordField() => find.byType(TextFormField).at(1);
  Finder loginButton() => find.widgetWithText(ElevatedButton, 'Login');

  group('LoginScreen Widget Tests', () {
    testWidgets('renders local visual content with empty email', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      expect(find.byType(Image), findsOneWidget);
      expect(
        (tester.widget<Image>(find.byType(Image)).image as AssetImage)
            .assetName,
        equals('assets/images/wedo_logo.png'),
      );
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Log in to reconnect with your vibe.'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('hello@wedo.social'), findsNothing);
      expect(
        tester.widget<TextFormField>(emailField()).controller!.text,
        isEmpty,
      );
    });

    testWidgets('validates blank email and password without submitting', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        buildSubject(
          onLogin: ({required email, required password}) async => calls++,
        ),
      );
      await tester.ensureVisible(loginButton());
      await tester.tap(loginButton());
      await tester.pump();
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
      expect(calls, equals(0));
    });

    testWidgets('normalizes email and preserves short raw password', (
      tester,
    ) async {
      String? capturedEmail;
      String? capturedPassword;
      await tester.pumpWidget(
        buildSubject(
          onLogin: ({required String email, required String password}) async {
            capturedEmail = email;
            capturedPassword = password;
          },
        ),
      );
      await tester.enterText(emailField(), '  ALEX@WeDo.Social  ');
      await tester.enterText(passwordField(), 'abc');
      await tester.ensureVisible(loginButton());
      await tester.tap(loginButton());
      await tester.pumpAndSettle();
      expect(capturedEmail, equals('alex@wedo.social'));
      expect(capturedPassword, equals('abc'));
    });

    testWidgets(
      'accepts 72 UTF-8 bytes and rejects 73 including Unicode bytes',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(onLogin: ({required email, required password}) async {}),
        );
        await tester.enterText(emailField(), 'user@wedo.social');
        await tester.enterText(passwordField(), List.filled(72, 'a').join());
        await tester.ensureVisible(loginButton());
        await tester.tap(loginButton());
        await tester.pumpAndSettle();
        expect(find.text('Password must not exceed 72 bytes'), findsNothing);

        final emoji = String.fromCharCode(0x1F600);
        await tester.enterText(
          passwordField(),
          '${List.filled(70, 'a').join()}$emoji',
        );
        await tester.tap(loginButton());
        await tester.pump();
        expect(find.text('Password must not exceed 72 bytes'), findsOneWidget);
      },
    );

    testWidgets('toggles password visibility', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: passwordField(),
                matching: find.byType(TextField),
              ),
            )
            .obscureText,
        isTrue,
      );
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: passwordField(),
                matching: find.byType(TextField),
              ),
            )
            .obscureText,
        isFalse,
      );
    });

    testWidgets('does not fake login when callback is null', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.enterText(emailField(), 'user@wedo.social');
      await tester.enterText(passwordField(), 'abc');
      await tester.ensureVisible(loginButton());
      await tester.tap(loginButton());
      await tester.pumpAndSettle();
      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets('prevents double submit while loading', (tester) async {
      final completer = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        buildSubject(
          onLogin: ({required email, required password}) {
            calls++;
            return completer.future;
          },
        ),
      );
      await tester.enterText(emailField(), 'user@wedo.social');
      await tester.enterText(passwordField(), 'abc');
      await tester.ensureVisible(loginButton());
      await tester.tap(loginButton());
      await tester.pump();
      expect(calls, equals(1));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      completer.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('fires Forgot Password and Create Account callbacks', (
      tester,
    ) async {
      var forgot = false;
      var create = false;
      await tester.pumpWidget(
        buildSubject(
          onForgotPassword: () => forgot = true,
          onCreateAccount: () => create = true,
        ),
      );
      await tester.tap(find.text('Forgot Password?'));
      await tester.pump();
      expect(forgot, isTrue);
      final createAccount = find.text('Create Account');
      await tester.ensureVisible(createAccount);
      await tester.tap(createAccount);
      await tester.pump();
      expect(create, isTrue);
    });

    testWidgets('renders without overflow at normal and compact phone sizes', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(buildSubject());
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(360, 640);
      await tester.pumpWidget(buildSubject());
      expect(tester.takeException(), isNull);
    });
  });
}
