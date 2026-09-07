import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/ui/widgets/primary_button.dart';
import 'package:mobile/features/auth/presentation/screens/verify_email_screen.dart';
import 'package:mobile/features/auth/presentation/widgets/otp_code_field.dart';

void main() {
  Widget buildSubject({
    String email = 'alex@wedo.social',
    VoidCallback? onBack,
    VoidCallback? onChangeEmail,
    int initialCooldownSeconds = 0,
    Future<void> Function(String code)? onVerify,
    Future<int?> Function()? onResend,
    VoidCallback? onVerificationSuccess,
  }) {
    return MaterialApp(
      home: VerifyEmailScreen(
        email: email,
        onBack: onBack ?? () {},
        onChangeEmail: onChangeEmail ?? () {},
        initialCooldownSeconds: initialCooldownSeconds,
        onVerify: onVerify,
        onResend: onResend,
        onVerificationSuccess: onVerificationSuccess,
      ),
    );
  }

  group('VerifyEmailScreen Widget Tests', () {
    testWidgets('renders passed email, title, 6 OTP inputs, buttons, and actions', (tester) async {
      await tester.pumpWidget(
        buildSubject(email: 'custom.user@wedo.social'),
      );

      // Header & Title
      expect(find.text('Check your email'), findsOneWidget);
      expect(find.textContaining('custom.user@wedo.social'), findsOneWidget);

      // Logo (not rotated)
      expect(find.byType(Image), findsOneWidget);

      // Exactly 6 OTP TextField cells
      final textFields = find.descendant(
        of: find.byType(OtpCodeField),
        matching: find.byType(TextField),
      );
      expect(textFields, findsNWidgets(6));

      // Buttons and actions
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text("Didn't receive the code?"), findsOneWidget);
      expect(find.text('Change email address'), findsOneWidget);

      // Back button
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });

    testWidgets('auto-advances focus and preserves leading zeros as a String', (tester) async {
      String? submittedCode;

      await tester.pumpWidget(
        buildSubject(
          onVerify: (code) async {
            submittedCode = code;
          },
        ),
      );

      final textFields = find.descendant(
        of: find.byType(OtpCodeField),
        matching: find.byType(TextField),
      );

      // Enter digits one by one starting with 00 (leading zeros)
      final digits = ['0', '0', '7', '8', '9', '2'];
      for (int i = 0; i < 6; i++) {
        await tester.enterText(textFields.at(i), digits[i]);
        await tester.pump();
      }

      final continueButton = find.widgetWithText(PrimaryButton, 'Continue');
      await tester.ensureVisible(continueButton);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      // Ensure leading zero survived and String is exactly "007892"
      expect(submittedCode, equals('007892'));
    });

    testWidgets('backward deletion navigates and clears previous cell', (tester) async {
      await tester.pumpWidget(buildSubject());

      final textFields = find.descendant(
        of: find.byType(OtpCodeField),
        matching: find.byType(TextField),
      );

      // Enter first digit '5'
      await tester.enterText(textFields.at(0), '5');
      await tester.pump();

      // Focus should be at cell 1. Send backspace on empty cell 1.
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      // Cell 0 should now be cleared
      final field0 = tester.widget<TextField>(textFields.at(0));
      expect(field0.controller?.text, isEmpty);
    });

    testWidgets('distributes pasted 6-digit code across all cells', (tester) async {
      String? submittedCode;

      await tester.pumpWidget(
        buildSubject(
          onVerify: (code) async {
            submittedCode = code;
          },
        ),
      );

      final textFields = find.descendant(
        of: find.byType(OtpCodeField),
        matching: find.byType(TextField),
      );

      // Paste 6-digit string into the first cell
      await tester.enterText(textFields.at(0), '012345');
      await tester.pump();

      for (int i = 0; i < 6; i++) {
        final field = tester.widget<TextField>(textFields.at(i));
        expect(field.controller?.text, equals('$i'));
      }

      final continueButton = find.widgetWithText(PrimaryButton, 'Continue');
      await tester.ensureVisible(continueButton);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      expect(submittedCode, equals('012345'));
    });

    testWidgets('validates incomplete code (< 6 digits) on Continue tap', (tester) async {
      var verifyCalled = false;

      await tester.pumpWidget(
        buildSubject(
          onVerify: (_) async {
            verifyCalled = true;
          },
        ),
      );

      final textFields = find.descendant(
        of: find.byType(OtpCodeField),
        matching: find.byType(TextField),
      );

      // Enter only 3 digits
      await tester.enterText(textFields.at(0), '1');
      await tester.enterText(textFields.at(1), '2');
      await tester.enterText(textFields.at(2), '3');
      await tester.pump();

      final continueButton = find.widgetWithText(PrimaryButton, 'Continue');
      await tester.ensureVisible(continueButton);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      expect(find.text('Please enter the complete 6-digit code'), findsOneWidget);
      expect(verifyCalled, isFalse);
    });

    testWidgets('does not call onVerificationSuccess when onVerify is null', (tester) async {
      var successCalled = false;

      await tester.pumpWidget(
        buildSubject(
          onVerify: null,
          onVerificationSuccess: () {
            successCalled = true;
          },
        ),
      );

      final textFields = find.descendant(
        of: find.byType(OtpCodeField),
        matching: find.byType(TextField),
      );
      for (int i = 0; i < 6; i++) {
        await tester.enterText(textFields.at(i), '$i');
      }

      final continueButton = find.widgetWithText(PrimaryButton, 'Continue');
      await tester.ensureVisible(continueButton);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      expect(successCalled, isFalse);
    });

    testWidgets('prevents double submission while verifying', (tester) async {
      final completer = Completer<void>();
      var callCount = 0;

      await tester.pumpWidget(
        buildSubject(
          onVerify: (_) async {
            callCount++;
            await completer.future;
          },
        ),
      );

      final textFields = find.descendant(
        of: find.byType(OtpCodeField),
        matching: find.byType(TextField),
      );
      for (int i = 0; i < 6; i++) {
        await tester.enterText(textFields.at(i), '9');
      }

      final buttonFinder = find.byType(ElevatedButton);
      await tester.ensureVisible(buttonFinder);

      // First tap
      await tester.tap(buttonFinder);
      await tester.pump();

      expect(callCount, equals(1));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // The button becomes disabled while the first submit is pending.
      expect(tester.widget<ElevatedButton>(buttonFinder).onPressed, isNull);
      expect(callCount, equals(1));

      completer.complete();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('disables OTP and Resend while verifying', (tester) async {
      final completer = Completer<void>();
      var resendCallCount = 0;

      await tester.pumpWidget(
        buildSubject(
          onVerify: (_) => completer.future,
          onResend: () async {
            resendCallCount++;
            return 30;
          },
        ),
      );

      final textFields = find.descendant(
        of: find.byType(OtpCodeField),
        matching: find.byType(TextField),
      );
      for (int i = 0; i < 6; i++) {
        await tester.enterText(textFields.at(i), '$i');
      }

      final continueButton = find.widgetWithText(PrimaryButton, 'Continue');
      await tester.ensureVisible(continueButton);
      await tester.tap(continueButton);
      await tester.pump();

      for (int i = 0; i < 6; i++) {
        expect(tester.widget<TextField>(textFields.at(i)).enabled, isFalse);
      }
      final resendButton = find.widgetWithText(TextButton, 'Resend Code');
      expect(tester.widget<TextButton>(resendButton).onPressed, isNull);
      expect(resendCallCount, equals(0));

      completer.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('disables OTP and Continue while resending', (tester) async {
      final completer = Completer<int?>();
      var verifyCallCount = 0;

      await tester.pumpWidget(
        buildSubject(
          onVerify: (_) async {
            verifyCallCount++;
          },
          onResend: () => completer.future,
        ),
      );

      final resendButton = find.widgetWithText(TextButton, 'Resend Code');
      await tester.ensureVisible(resendButton);
      await tester.tap(resendButton);
      await tester.pump();

      final textFields = find.descendant(
        of: find.byType(OtpCodeField),
        matching: find.byType(TextField),
      );
      for (int i = 0; i < 6; i++) {
        expect(tester.widget<TextField>(textFields.at(i)).enabled, isFalse);
      }
      final continueButton = tester.widget<ElevatedButton>(
        find.descendant(
          of: find.widgetWithText(PrimaryButton, 'Continue'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(continueButton.onPressed, isNull);
      expect(verifyCallCount, equals(0));

      completer.complete(30);
      await tester.pumpAndSettle();
    });

    testWidgets('respects injected initial cooldown and disables Resend during cooldown', (tester) async {
      // Injected with 45s (verifying NO hardcoded 60s)
      await tester.pumpWidget(
        buildSubject(initialCooldownSeconds: 45),
      );

      expect(find.text('Resend in 0:45'), findsOneWidget);
      expect(find.text('Resend Code'), findsNothing);

      // Advance timer by 45 seconds
      await tester.pump(const Duration(seconds: 45));

      expect(find.text('Resend Code'), findsOneWidget);
      expect(find.textContaining('Resend in'), findsNothing);
    });

    testWidgets('onResend returned value restarts cooldown with RETURNED VALUE', (tester) async {
      var resendCallCount = 0;

      await tester.pumpWidget(
        buildSubject(
          initialCooldownSeconds: 0,
          onResend: () async {
            resendCallCount++;
            // Returns 30s instead of 60s to prove no hardcoded 60
            return 30;
          },
        ),
      );

      expect(find.text('Resend Code'), findsOneWidget);

      final resendButton = find.widgetWithText(TextButton, 'Resend Code');
      await tester.ensureVisible(resendButton);
      await tester.tap(resendButton);
      await tester.pump();

      expect(resendCallCount, equals(1));
      // Proves countdown was set to the returned 30s!
      expect(find.text('Resend in 0:30'), findsOneWidget);
    });

    testWidgets('fires Back, Resend, and Change email callbacks', (tester) async {
      var backTapped = false;
      var changeEmailTapped = false;
      var resendTapped = false;

      await tester.pumpWidget(
        buildSubject(
          onBack: () {
            backTapped = true;
          },
          onChangeEmail: () {
            changeEmailTapped = true;
          },
          onResend: () async {
            resendTapped = true;
            return null;
          },
        ),
      );

      // Tap Back
      final backButton = find.byIcon(Icons.arrow_back_rounded);
      await tester.tap(backButton);
      await tester.pump();
      expect(backTapped, isTrue);

      // Tap Resend Code
      final resendCode = find.widgetWithText(TextButton, 'Resend Code');
      await tester.ensureVisible(resendCode);
      await tester.tap(resendCode);
      await tester.pump();
      expect(resendTapped, isTrue);

      // Tap Change email address
      final changeEmail = find.text('Change email address');
      await tester.ensureVisible(changeEmail);
      await tester.tap(changeEmail);
      await tester.pump();
      expect(changeEmailTapped, isTrue);
    });

    testWidgets('renders without overflow at normal and compact phone sizes', (tester) async {
      // 390 x 844 (standard modern smartphone)
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildSubject(initialCooldownSeconds: 60));
      expect(tester.takeException(), isNull);

      // 360 x 640 (compact smartphone with 6 OTP cells)
      tester.view.physicalSize = const Size(360, 640);
      await tester.pumpWidget(buildSubject(initialCooldownSeconds: 60));
      expect(tester.takeException(), isNull);
    });
  });
}
