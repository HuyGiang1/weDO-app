import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/routes.dart';
import 'package:mobile/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:mobile/features/auth/presentation/screens/verify_email_screen.dart';

void main() {
  group('AppRoutes ResetPassword route', () {
    test(
      'returns no route when ResetPassword arguments are absent or blank',
      () {
        expect(
          AppRoutes.onGenerateRoute(
            const RouteSettings(name: AppRoutes.resetPassword),
          ),
          isNull,
        );
        expect(
          AppRoutes.onGenerateRoute(
            const RouteSettings(
              name: AppRoutes.resetPassword,
              arguments: ResetPasswordRouteArgs(email: '   '),
            ),
          ),
          isNull,
        );
      },
    );

    testWidgets('builds ResetPassword route from its email-only arguments', (
      tester,
    ) async {
      final route = AppRoutes.onGenerateRoute(
        const RouteSettings(
          name: AppRoutes.resetPassword,
          arguments: ResetPasswordRouteArgs(email: 'reset@wedo.social'),
        ),
      );
      expect(route, isNotNull);
      expect(route!.settings.arguments, isA<ResetPasswordRouteArgs>());
      final materialRoute = route as MaterialPageRoute<void>;
      await tester.pumpWidget(
        MaterialApp(home: Builder(builder: materialRoute.builder)),
      );
      final screen = tester.widget<ResetPasswordScreen>(
        find.byType(ResetPasswordScreen),
      );
      expect(screen.email, 'reset@wedo.social');
      expect(screen.onSubmit, isNull);
    });
  });
  group('AppRoutes VerifyEmail route', () {
    test(
      'returns no route when VerifyEmail arguments are absent or invalid',
      () {
        expect(
          AppRoutes.onGenerateRoute(
            const RouteSettings(name: AppRoutes.verifyEmail),
          ),
          isNull,
        );
        expect(
          AppRoutes.onGenerateRoute(
            const RouteSettings(
              name: AppRoutes.verifyEmail,
              arguments: 'user@wedo.social',
            ),
          ),
          isNull,
        );
        expect(
          AppRoutes.onGenerateRoute(
            const RouteSettings(
              name: AppRoutes.verifyEmail,
              arguments: VerifyEmailRouteArgs(
                email: '',
                initialCooldownSeconds: 0,
              ),
            ),
          ),
          isNull,
        );
      },
    );

    testWidgets('uses only the supplied route arguments', (tester) async {
      final route = AppRoutes.onGenerateRoute(
        const RouteSettings(
          name: AppRoutes.verifyEmail,
          arguments: VerifyEmailRouteArgs(
            email: 'real.user@wedo.social',
            initialCooldownSeconds: 17,
          ),
        ),
      );

      expect(route, isA<MaterialPageRoute<void>>());
      final materialRoute = route! as MaterialPageRoute<void>;
      await tester.pumpWidget(
        MaterialApp(home: Builder(builder: materialRoute.builder)),
      );

      expect(find.byType(VerifyEmailScreen), findsOneWidget);
      expect(find.textContaining('real.user@wedo.social'), findsOneWidget);
      expect(find.text('Resend in 0:17'), findsOneWidget);
      expect(find.text('user@wedo.social'), findsNothing);
    });
  });
}
