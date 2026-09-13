import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/data/auth_failure.dart';
import 'package:mobile/features/profile/presentation/screens/change_password_screen.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    Future<void> Function({
      required String currentPassword,
      required String newPassword,
    })?
    changePassword,
    Future<bool> Function()? endSessionAfterPasswordChange,
    VoidCallback? onSuccess,
  }) => tester.pumpWidget(
    MaterialApp(
      home: ChangePasswordScreen(
        changePassword:
            changePassword ??
            ({required currentPassword, required newPassword}) async {},
        endSessionAfterPasswordChange:
            endSessionAfterPasswordChange ?? () async => true,
        onSuccess: onSuccess ?? () {},
      ),
    ),
  );

  Future<void> enterPasswords(
    WidgetTester tester, {
    required String current,
    required String next,
    required String confirmation,
  }) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), current);
    await tester.enterText(fields.at(1), next);
    await tester.enterText(fields.at(2), confirmation);
  }

  testWidgets(
    'submits raw password values then locally ends the session on success',
    (tester) async {
      String? current;
      String? next;
      var endSessionCalls = 0;
      var successCalls = 0;
      await pumpScreen(
        tester,
        changePassword:
            ({required currentPassword, required newPassword}) async {
              current = currentPassword;
              next = newPassword;
            },
        endSessionAfterPasswordChange: () async {
          endSessionCalls++;
          return true;
        },
        onSuccess: () => successCalls++,
      );

      await enterPasswords(
        tester,
        current: ' current raw ',
        next: ' new raw ',
        confirmation: ' new raw ',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
      await tester.pump();

      expect(current, ' current raw ');
      expect(next, ' new raw ');
      expect(endSessionCalls, 1);
      expect(successCalls, 1);
    },
  );

  testWidgets(
    'client validation blocks mismatches and UTF-8 passwords exceeding 72 bytes',
    (tester) async {
      var remoteCalls = 0;
      await pumpScreen(
        tester,
        changePassword:
            ({required currentPassword, required newPassword}) async {
              remoteCalls++;
            },
      );

      await enterPasswords(
        tester,
        current: 'OldPassword123!',
        next: 'abcdefgh',
        confirmation: 'different',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
      await tester.pump();
      expect(find.text('Passwords do not match'), findsOneWidget);
      expect(remoteCalls, 0);

    final oversizedUtf8 = List.filled(25, '\u1e7f').join();
      await enterPasswords(
        tester,
        current: 'OldPassword123!',
        next: oversizedUtf8,
        confirmation: oversizedUtf8,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
      await tester.pump();
      expect(find.text('Password must not exceed 72 bytes'), findsOneWidget);
      expect(remoteCalls, 0);
    },
  );

  testWidgets(
    'wrong current password displays a field-safe error and preserves local session',
    (tester) async {
      var invalidationCalls = 0;
      await pumpScreen(
        tester,
        changePassword:
            ({required currentPassword, required newPassword}) async {
              throw const AuthException(
          AuthFailure(
            AuthFailureType.invalidCredentials,
            backendCode: 'AUTH_INVALID_CREDENTIALS',
          ),
              );
            },
        endSessionAfterPasswordChange: () async {
          invalidationCalls++;
          return true;
        },
      );

      await enterPasswords(
        tester,
        current: 'WrongPassword123!',
        next: 'NewPassword456!',
        confirmation: 'NewPassword456!',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
      await tester.pumpAndSettle();

      expect(find.text('Current password is incorrect'), findsOneWidget);
      expect(invalidationCalls, 0);
    },
  );

  testWidgets('ambiguous network failure does not clear the local session', (
    tester,
  ) async {
    var invalidationCalls = 0;
    final request = Completer<void>();
    await pumpScreen(
      tester,
      changePassword: ({required currentPassword, required newPassword}) =>
          request.future,
      endSessionAfterPasswordChange: () async {
        invalidationCalls++;
        return true;
      },
    );

    await enterPasswords(
      tester,
      current: 'OldPassword123!',
      next: 'NewPassword456!',
      confirmation: 'NewPassword456!',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
    await tester.pump();
    request.completeError(StateError('network unavailable'));
    await tester.pump();

    expect(
      find.text('Unable to change password. Please try again.'),
      findsOneWidget,
    );
    expect(invalidationCalls, 0);
  });
}
