import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/presentation/screens/forgot_password_screen.dart';

void main() {
  Widget buildSubject({
    Future<bool> Function({required String email})? onSubmit,
    VoidCallback? onBack,
    VoidCallback? onReturnToLogin,
    ValueChanged<String>? onRequestSuccess,
  }) => MaterialApp(
    home: ForgotPasswordScreen(
      onSubmit: onSubmit,
      onBack: onBack ?? () {},
      onReturnToLogin: onReturnToLogin ?? () {},
      onRequestSuccess: onRequestSuccess,
    ),
  );

  Finder emailField() => find.byType(TextFormField);
  Finder submitButton() =>
      find.widgetWithText(ElevatedButton, 'Send Reset Code');

  group('ForgotPasswordScreen Widget Tests', () {
    testWidgets('renders approved local visual content', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(Image), findsOneWidget);
      expect(
        (tester.widget<Image>(find.byType(Image)).image as AssetImage)
            .assetName,
        equals('assets/images/wedo_logo.png'),
      );
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(
        find.text(
          "Enter your email and we'll send a 6-digit reset code if an account exists.",
        ),
        findsOneWidget,
      );
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.byIcon(Icons.mail_outline), findsOneWidget);
      expect(find.text('you@example.com'), findsOneWidget);
      expect(find.text('Send Reset Code'), findsOneWidget);
      expect(find.text('Return to Login'), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsNothing);
      expect(find.textContaining('http'), findsNothing);
      expect(
        tester.widget<TextFormField>(emailField()).controller!.text,
        isEmpty,
      );
    });

    testWidgets('rejects blank and whitespace-only email without submitting', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        buildSubject(
          onSubmit: ({required email}) async {
            calls++;
            return true;
          },
        ),
      );

      await tester.ensureVisible(submitButton());
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(find.text('Email is required'), findsOneWidget);
      expect(calls, equals(0));

      await tester.enterText(emailField(), '   ');
      await tester.tap(submitButton());
      await tester.pump();
      expect(find.text('Email is required'), findsOneWidget);
      expect(calls, equals(0));
    });

    testWidgets('allows nonblank local email and normalizes callback value', (
      tester,
    ) async {
      String? capturedEmail;
      await tester.pumpWidget(
        buildSubject(
          onSubmit: ({required String email}) async {
            capturedEmail = email;
            return true;
          },
        ),
      );

      await tester.enterText(emailField(), '  ALEX@WeDo.Social  ');
      await tester.ensureVisible(submitButton());
      await tester.tap(submitButton());
      await tester.pumpAndSettle();

      expect(capturedEmail, equals('alex@wedo.social'));
    });

    testWidgets('null callback does not fake neutral success', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.enterText(emailField(), 'user@wedo.social');
      await tester.ensureVisible(submitButton());
      await tester.tap(submitButton());
      await tester.pumpAndSettle();

      expect(
        find.text(
          'If an account with this email exists, a 6-digit reset code will be sent.',
        ),
        findsNothing,
      );
    });

    testWidgets('shows exact neutral success only after callback succeeds', (
      tester,
    ) async {
      var successCalls = 0;
      await tester.pumpWidget(
        buildSubject(
          onSubmit: ({required email}) async => true,
          onRequestSuccess: (_) => successCalls++,
        ),
      );
      await tester.enterText(emailField(), 'user@wedo.social');
      await tester.ensureVisible(submitButton());
      await tester.tap(submitButton());
      await tester.pumpAndSettle();

      expect(
        find.text(
          'If an account with this email exists, a 6-digit reset code will be sent.',
        ),
        findsOneWidget,
      );
      expect(successCalls, equals(1));
      expect(find.textContaining('Account found'), findsNothing);
      expect(find.textContaining('does not exist'), findsNothing);
    });

    testWidgets(
      'does not show success or navigate when callback returns false',
      (tester) async {
        var successCalls = 0;
        await tester.pumpWidget(
          buildSubject(
            onSubmit: ({required email}) async => false,
            onRequestSuccess: (_) => successCalls++,
          ),
        );
        await tester.enterText(emailField(), 'user@wedo.social');
        await tester.ensureVisible(submitButton());
        await tester.tap(submitButton());
        await tester.pumpAndSettle();

        expect(
          find.text(
            'If an account with this email exists, a 6-digit reset code will be sent.',
          ),
          findsNothing,
        );
        expect(successCalls, 0);
        expect(
          tester.widget<ElevatedButton>(submitButton()).onPressed,
          isNotNull,
        );
      },
    );

    testWidgets('prevents double submit while loading', (tester) async {
      final completer = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        buildSubject(
          onSubmit: ({required email}) async {
            calls++;
            await completer.future;
            return true;
          },
        ),
      );
      await tester.enterText(emailField(), 'user@wedo.social');
      await tester.ensureVisible(submitButton());
      await tester.tap(submitButton());
      await tester.pump();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(calls, equals(1));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      completer.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('fires Back and Return to Login callbacks', (tester) async {
      var back = false;
      var returnToLogin = false;
      await tester.pumpWidget(
        buildSubject(
          onBack: () => back = true,
          onReturnToLogin: () => returnToLogin = true,
        ),
      );

      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      expect(back, isTrue);
      final returnButton = find.text('Return to Login');
      await tester.ensureVisible(returnButton);
      await tester.tap(returnButton);
      await tester.pump();
      expect(returnToLogin, isTrue);
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
