import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/presentation/screens/reset_password_screen.dart';

void main() {
  const suppliedEmail = 'Reset.Owner@WeDo.Social ';

  Widget buildSubject({
    Future<void> Function({
      required String email,
      required String code,
      required String newPassword,
    })?
    onSubmit,
    VoidCallback? onBackToLogin,
    VoidCallback? onResetSuccess,
  }) => MaterialApp(
    home: ResetPasswordScreen(
      email: suppliedEmail,
      onSubmit: onSubmit,
      onBackToLogin: onBackToLogin ?? () {},
      onResetSuccess: onResetSuccess,
    ),
  );

  Finder fieldAt(int index) => find.byType(TextFormField).at(index);
  Finder codeField() => fieldAt(0);
  Finder newPasswordField() => fieldAt(1);
  Finder confirmPasswordField() => fieldAt(2);
  Finder updateButton() =>
      find.widgetWithText(ElevatedButton, 'Update Password');

  Future<void> enterValidForm(
    WidgetTester tester, {
    String password = 'abcdefgh',
  }) async {
    await tester.enterText(codeField(), '012345');
    await tester.enterText(newPasswordField(), password);
    await tester.enterText(confirmPasswordField(), password);
  }

  group('ResetPasswordScreen Widget Tests', () {
    testWidgets('renders corrected local visual content and truthful rules', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(Image), findsOneWidget);
      expect(
        (tester.widget<Image>(find.byType(Image)).image as AssetImage)
            .assetName,
        equals('assets/images/wedo_logo.png'),
      );
      expect(find.text('New Password'), findsNWidgets(2));
      expect(
        find.text('Choose a password with 8–72 characters.'),
        findsOneWidget,
      );
      expect(find.text('Reset Code'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.text('Password requirements:'), findsOneWidget);
      expect(find.text('8–72 characters'), findsOneWidget);
      expect(find.text('At most 72 UTF-8 bytes'), findsOneWidget);
      expect(find.text('Update Password'), findsOneWidget);
      expect(find.text('Back to Login'), findsOneWidget);
      expect(find.textContaining('previously used'), findsNothing);
      expect(find.textContaining('At least 1 number'), findsNothing);
      expect(find.textContaining('At least 1 special'), findsNothing);
      expect(find.textContaining('Uppercase'), findsNothing);
    });

    testWidgets('validates reset code shape and preserves leading zero', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        buildSubject(
          onSubmit: ({
            required email,
            required code,
            required newPassword,
          }) async => calls++,
        ),
      );
      await tester.enterText(newPasswordField(), 'abcdefgh');
      await tester.enterText(confirmPasswordField(), 'abcdefgh');
      await tester.ensureVisible(updateButton());
      await tester.tap(updateButton());
      await tester.pump();
      expect(find.text('Reset code is required'), findsOneWidget);

      await tester.enterText(codeField(), '123');
      await tester.tap(updateButton());
      await tester.pump();
      expect(find.text('Enter a valid 6-digit reset code'), findsOneWidget);

      tester.widget<TextFormField>(codeField()).controller!.text = '1234567';
      await tester.tap(updateButton());
      await tester.pump();
      expect(find.text('Enter a valid 6-digit reset code'), findsOneWidget);

      await tester.enterText(codeField(), 'abcdef');
      await tester.tap(updateButton());
      await tester.pump();
      expect(find.text('Reset code is required'), findsOneWidget);

      await tester.enterText(codeField(), '012345');
      await tester.tap(updateButton());
      await tester.pumpAndSettle();
      expect(calls, equals(1));
    });

    testWidgets('enforces exact backend password and confirmation rules', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.enterText(codeField(), '012345');
      await tester.enterText(newPasswordField(), '       ');
      await tester.enterText(confirmPasswordField(), '       ');
      await tester.ensureVisible(updateButton());
      await tester.tap(updateButton());
      await tester.pump();
      expect(find.text('Password is required'), findsOneWidget);

      await tester.enterText(newPasswordField(), '1234567');
      await tester.enterText(confirmPasswordField(), '1234567');
      await tester.tap(updateButton());
      await tester.pump();
      expect(
        find.text('Password must be between 8 and 72 characters'),
        findsOneWidget,
      );

      await tester.enterText(newPasswordField(), 'a' * 73);
      await tester.enterText(confirmPasswordField(), 'a' * 73);
      await tester.tap(updateButton());
      await tester.pump();
      expect(
        find.text('Password must be between 8 and 72 characters'),
        findsOneWidget,
      );

      final emoji = String.fromCharCode(0x1F600);
      final overBytePassword = '${List.filled(69, 'a').join()}$emoji';
      await tester.enterText(newPasswordField(), overBytePassword);
      await tester.enterText(confirmPasswordField(), overBytePassword);
      await tester.tap(updateButton());
      await tester.pump();
      expect(find.text('Password must not exceed 72 bytes'), findsOneWidget);

      await tester.enterText(newPasswordField(), 'abcdefgh');
      await tester.enterText(confirmPasswordField(), 'abcdefgh');
      await tester.tap(updateButton());
      await tester.pumpAndSettle();
      expect(find.text('Password must not exceed 72 bytes'), findsNothing);

      await tester.enterText(newPasswordField(), 'abcdefgh');
      await tester.enterText(confirmPasswordField(), 'abcdefghi');
      await tester.tap(updateButton());
      await tester.pump();
      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets(
      'forwards supplied email, leading-zero code, and raw password',
      (tester) async {
        String? capturedEmail;
        String? capturedCode;
        String? capturedPassword;
        await tester.pumpWidget(
          buildSubject(
            onSubmit:
                ({
                  required String email,
                  required String code,
                  required String newPassword,
                }) async {
                  capturedEmail = email;
                  capturedCode = code;
                  capturedPassword = newPassword;
                },
          ),
        );
        await enterValidForm(tester, password: ' raw pass ');
        await tester.ensureVisible(updateButton());
        await tester.tap(updateButton());
        await tester.pumpAndSettle();

        expect(capturedEmail, equals(suppliedEmail));
        expect(capturedCode, equals('012345'));
        expect(capturedPassword, equals(' raw pass '));
      },
    );

    testWidgets('visibility toggles independently', (tester) async {
      await tester.pumpWidget(buildSubject());
      final newTextField = find.descendant(
        of: newPasswordField(),
        matching: find.byType(TextField),
      );
      final confirmTextField = find.descendant(
        of: confirmPasswordField(),
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(newTextField).obscureText, isTrue);
      expect(tester.widget<TextField>(confirmTextField).obscureText, isTrue);

      await tester.tap(find.byTooltip('Show new password'));
      await tester.pump();
      expect(tester.widget<TextField>(newTextField).obscureText, isFalse);
      expect(tester.widget<TextField>(confirmTextField).obscureText, isTrue);

      await tester.tap(find.byTooltip('Show confirm password'));
      await tester.pump();
      expect(tester.widget<TextField>(newTextField).obscureText, isFalse);
      expect(tester.widget<TextField>(confirmTextField).obscureText, isFalse);
    });

    testWidgets('null callback does not fake success', (tester) async {
      await tester.pumpWidget(buildSubject());
      await enterValidForm(tester);
      await tester.ensureVisible(updateButton());
      await tester.tap(updateButton());
      await tester.pumpAndSettle();
      expect(find.text('Password updated. You can now log in.'), findsNothing);
    });

    testWidgets('prevents double submit and shows success after callback', (
      tester,
    ) async {
      final completer = Completer<void>();
      var calls = 0;
      var successCalls = 0;
      await tester.pumpWidget(
        buildSubject(
          onSubmit: ({required email, required code, required newPassword}) {
            calls++;
            return completer.future;
          },
          onResetSuccess: () => successCalls++,
        ),
      );
      await enterValidForm(tester);
      await tester.ensureVisible(updateButton());
      await tester.tap(updateButton());
      await tester.pump();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(calls, equals(1));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete();
      await tester.pumpAndSettle();
      expect(
        find.text('Password updated. You can now log in.'),
        findsOneWidget,
      );
      expect(successCalls, equals(1));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('fires Back to Login callback', (tester) async {
      var returned = false;
      await tester.pumpWidget(
        buildSubject(onBackToLogin: () => returned = true),
      );
      final backButton = find.text('Back to Login');
      await tester.ensureVisible(backButton);
      await tester.tap(backButton);
      await tester.pump();
      expect(returned, isTrue);
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
