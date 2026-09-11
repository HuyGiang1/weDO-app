import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/routes.dart';
import 'package:mobile/features/auth/application/auth_session_controller.dart';
import 'package:mobile/features/auth/presentation/auth_flow_coordinator.dart';
import 'package:mobile/features/auth/presentation/screens/create_username_screen.dart';
import 'package:mobile/features/auth/presentation/screens/verify_email_screen.dart';
import 'package:mobile/features/auth/data/models/auth_models.dart';

void main() {
  group('AppRoutes Registry', () {
    test('contains exactly 9 registered production routes', () {
      expect(AppRoutes.routes.length, 9);

      final expectedRoutes = <String>{
        AppRoutes.welcome,
        AppRoutes.register,
        AppRoutes.verifyEmail,
        AppRoutes.login,
        AppRoutes.forgotPassword,
        AppRoutes.resetPassword,
        AppRoutes.createUsername,
        AppRoutes.completeProfile,
        AppRoutes.profile,
      };

      expect(AppRoutes.routes.keys.toSet(), expectedRoutes);
    });

    test('every registered route has explicit access metadata', () {
      for (final entry in AppRoutes.routes.entries) {
        expect(
          entry.value.access,
          entry.key == AppRoutes.profile
              ? AppRouteAccess.authenticated
              : AppRouteAccess.public,
          reason: 'Route ${entry.key} must declare its intended access',
        );
      }
    });
  });

  group('Protected Profile Route', () {
    Future<CurrentUser> loadUser() async => const CurrentUser(
      id: 'user-id',
      email: 'user@wedo.social',
      status: 'ACTIVE',
      emailVerified: true,
    );

    RouteSettings settings() => RouteSettings(
      name: AppRoutes.profile,
      arguments: loadUser,
    );

    test('allows the profile route only for authenticated sessions', () {
      expect(
        AppRoutes.onGenerateRoute(
          settings(),
          authStatus: AuthSessionStatus.authenticated,
        ),
        isA<MaterialPageRoute<void>>(),
      );
      expect(
        AppRoutes.onGenerateRoute(
          settings(),
          authStatus: AuthSessionStatus.unauthenticated,
        ),
        isNull,
      );
      expect(
        AppRoutes.onGenerateRoute(
          settings(),
          authStatus: AuthSessionStatus.restoring,
        ),
        isNull,
      );
    });

    test('fails closed when the authenticated profile route has no loader', () {
      expect(
        AppRoutes.onGenerateRoute(
          const RouteSettings(name: AppRoutes.profile),
          authStatus: AuthSessionStatus.authenticated,
        ),
        isNull,
      );
    });
  });

  group('Public Route Generation Across Session Statuses', () {
    const statuses = [
      AuthSessionStatus.restoring,
      AuthSessionStatus.unauthenticated,
      AuthSessionStatus.authenticated,
    ];

    for (final status in statuses) {
      test('generates welcome route under $status', () {
        final route = AppRoutes.onGenerateRoute(
          const RouteSettings(name: AppRoutes.welcome),
          authStatus: status,
        );

        expect(route, isNotNull);
        expect(route, isA<MaterialPageRoute<void>>());
      });

      test('generates login route under $status', () {
        final route = AppRoutes.onGenerateRoute(
          const RouteSettings(name: AppRoutes.login),
          authStatus: status,
        );

        expect(route, isNotNull);
        expect(route, isA<MaterialPageRoute<void>>());
      });

      test('generates register route under $status', () {
        final route = AppRoutes.onGenerateRoute(
          const RouteSettings(name: AppRoutes.register),
          authStatus: status,
        );

        expect(route, isNotNull);
        expect(route, isA<MaterialPageRoute<void>>());
      });

      test('generates forgotPassword route under $status', () {
        final route = AppRoutes.onGenerateRoute(
          const RouteSettings(name: AppRoutes.forgotPassword),
          authStatus: status,
        );

        expect(route, isNotNull);
        expect(route, isA<MaterialPageRoute<void>>());
      });
    }
  });

  group('Route Argument Validation Fail-Closed Regression', () {
    const authStatus = AuthSessionStatus.unauthenticated;

    group('VerifyEmail route args', () {
      test('returns null when arguments are null', () {
        final route = AppRoutes.onGenerateRoute(
          const RouteSettings(name: AppRoutes.verifyEmail),
          authStatus: authStatus,
        );
        expect(route, isNull);
      });

      test('returns null when arguments are wrong type', () {
        final route = AppRoutes.onGenerateRoute(
          const RouteSettings(
            name: AppRoutes.verifyEmail,
            arguments: 'user@example.com',
          ),
          authStatus: authStatus,
        );
        expect(route, isNull);
      });

      test('returns null when VerifyEmailRouteArgs email is empty', () {
        final route = AppRoutes.onGenerateRoute(
          const RouteSettings(
            name: AppRoutes.verifyEmail,
            arguments: VerifyEmailRouteArgs(
              email: '',
              initialCooldownSeconds: 30,
            ),
          ),
          authStatus: authStatus,
        );
        expect(route, isNull);
      });

      test('returns null when VerifyEmailRouteArgs initialCooldownSeconds is negative', () {
        final route = AppRoutes.onGenerateRoute(
          const RouteSettings(
            name: AppRoutes.verifyEmail,
            arguments: VerifyEmailRouteArgs(
              email: 'user@example.com',
              initialCooldownSeconds: -1,
            ),
          ),
          authStatus: authStatus,
        );
        expect(route, isNull);
      });

      test('generates route when VerifyEmailRouteArgs are valid', () {
        final route = AppRoutes.onGenerateRoute(
          const RouteSettings(
            name: AppRoutes.verifyEmail,
            arguments: VerifyEmailRouteArgs(
              email: 'user@example.com',
              initialCooldownSeconds: 30,
            ),
          ),
          authStatus: authStatus,
        );
        expect(route, isNotNull);
        expect(route, isA<MaterialPageRoute<void>>());
      });

      test('generates route when VerifyEmailFlowArgs are valid', () {
        final route = AppRoutes.onGenerateRoute(
          RouteSettings(
            name: AppRoutes.verifyEmail,
            arguments: VerifyEmailFlowArgs(
              email: 'user@example.com',
              onVerify: (_) async {},
              onResend: () async => null,
            ),
          ),
          authStatus: authStatus,
        );
        expect(route, isNotNull);
        expect(route, isA<MaterialPageRoute<void>>());
      });

      testWidgets('uses only the supplied route arguments', (tester) async {
        final route = AppRoutes.onGenerateRoute(
          const RouteSettings(
            name: AppRoutes.verifyEmail,
            arguments: VerifyEmailRouteArgs(
              email: 'real.user@wedo.social',
              initialCooldownSeconds: 17,
            ),
          ),
          authStatus: authStatus,
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

    group('ResetPassword route args', () {
      test('returns null when arguments are null', () {
        final route = AppRoutes.onGenerateRoute(
          const RouteSettings(name: AppRoutes.resetPassword),
          authStatus: authStatus,
        );
        expect(route, isNull);
      });

      test('returns null when arguments are wrong type', () {
        final route = AppRoutes.onGenerateRoute(
          const RouteSettings(
            name: AppRoutes.resetPassword,
            arguments: 12345,
          ),
          authStatus: authStatus,
        );
        expect(route, isNull);
      });

      test('returns null when ResetPasswordRouteArgs email is empty or whitespace', () {
        final emptyRoute = AppRoutes.onGenerateRoute(
          const RouteSettings(
            name: AppRoutes.resetPassword,
            arguments: ResetPasswordRouteArgs(email: ''),
          ),
          authStatus: authStatus,
        );
        expect(emptyRoute, isNull);

        final whitespaceRoute = AppRoutes.onGenerateRoute(
          const RouteSettings(
            name: AppRoutes.resetPassword,
            arguments: ResetPasswordRouteArgs(email: '   '),
          ),
          authStatus: authStatus,
        );
        expect(whitespaceRoute, isNull);
      });

      test('generates route when ResetPasswordRouteArgs are valid', () {
        final route = AppRoutes.onGenerateRoute(
          const RouteSettings(
            name: AppRoutes.resetPassword,
            arguments: ResetPasswordRouteArgs(email: 'user@example.com'),
          ),
          authStatus: authStatus,
        );
        expect(route, isNotNull);
        expect(route, isA<MaterialPageRoute<void>>());
      });
    });

    group('CreateUsername route args', () {
      test('returns null when arguments are null', () {
        final route = AppRoutes.onGenerateRoute(
          const RouteSettings(name: AppRoutes.createUsername),
          authStatus: authStatus,
        );
        expect(route, isNull);
      });

      test('returns null when arguments are wrong type', () {
        final route = AppRoutes.onGenerateRoute(
          const RouteSettings(
            name: AppRoutes.createUsername,
            arguments: 'my_user',
          ),
          authStatus: authStatus,
        );
        expect(route, isNull);
      });

      test('generates route when CreateUsernameFlowArgs are valid', () {
        final route = AppRoutes.onGenerateRoute(
          RouteSettings(
            name: AppRoutes.createUsername,
            arguments: CreateUsernameFlowArgs(
              onCheckAvailability: (_) async => UsernameAvailability.available,
              onContinue: (_) async {},
            ),
          ),
          authStatus: authStatus,
        );
        expect(route, isNotNull);
        expect(route, isA<MaterialPageRoute<void>>());
      });
    });

    group('CompleteProfile route args', () {
      test('returns null when arguments are null', () {
        final route = AppRoutes.onGenerateRoute(
          const RouteSettings(name: AppRoutes.completeProfile),
          authStatus: authStatus,
        );
        expect(route, isNull);
      });

      test('returns null when arguments are wrong type', () {
        final route = AppRoutes.onGenerateRoute(
          const RouteSettings(
            name: AppRoutes.completeProfile,
            arguments: {'username': 'my_user'},
          ),
          authStatus: authStatus,
        );
        expect(route, isNull);
      });

      test('generates route when CompleteProfileFlowArgs are valid', () {
        final route = AppRoutes.onGenerateRoute(
          RouteSettings(
            name: AppRoutes.completeProfile,
            arguments: CompleteProfileFlowArgs(
              username: 'user_1',
              onContinue: (_) async {},
            ),
          ),
          authStatus: authStatus,
        );
        expect(route, isNotNull);
        expect(route, isA<MaterialPageRoute<void>>());
      });
    });
  });

  group('Unknown Route Handling', () {
    const statuses = [
      AuthSessionStatus.restoring,
      AuthSessionStatus.unauthenticated,
      AuthSessionStatus.authenticated,
    ];

    for (final status in statuses) {
      test('returns null for unregistered route under $status', () {
        expect(
          AppRoutes.onGenerateRoute(
            const RouteSettings(name: '/unknown-route'),
            authStatus: status,
          ),
          isNull,
        );

        expect(
          AppRoutes.onGenerateRoute(
            const RouteSettings(name: '/home'),
            authStatus: status,
          ),
          isNull,
        );

        expect(
          AppRoutes.onGenerateRoute(
            const RouteSettings(name: '/dashboard'),
            authStatus: status,
          ),
          isNull,
        );
      });

      test('returns null for null route name under $status', () {
        expect(
          AppRoutes.onGenerateRoute(
            const RouteSettings(name: null),
            authStatus: status,
          ),
          isNull,
        );
      });
    }
  });

  group('Denied-Builder Policy (Test-Only Seam)', () {
    test(
      'builder is never invoked when route is authenticated-required and status is unauthenticated',
      () {
        var builderInvocations = 0;
        final testProtectedDef = AppRouteDefinition(
          access: AppRouteAccess.authenticated,
          builder: (settings, coordinator) {
            builderInvocations++;
            return MaterialPageRoute<void>(
              builder: (_) => const SizedBox.shrink(),
              settings: settings,
            );
          },
        );

        final route = AppRoutes.evaluateAndBuildRoute(
          testProtectedDef,
          const RouteSettings(name: '/test-protected'),
          authStatus: AuthSessionStatus.unauthenticated,
        );

        expect(route, isNull);
        expect(builderInvocations, 0);
      },
    );

    test(
      'builder is never invoked when route is authenticated-required and status is restoring',
      () {
        var builderInvocations = 0;
        final testProtectedDef = AppRouteDefinition(
          access: AppRouteAccess.authenticated,
          builder: (settings, coordinator) {
            builderInvocations++;
            return MaterialPageRoute<void>(
              builder: (_) => const SizedBox.shrink(),
              settings: settings,
            );
          },
        );

        final route = AppRoutes.evaluateAndBuildRoute(
          testProtectedDef,
          const RouteSettings(name: '/test-protected'),
          authStatus: AuthSessionStatus.restoring,
        );

        expect(route, isNull);
        expect(builderInvocations, 0);
      },
    );

    test(
      'builder is invoked when route is authenticated-required and status is authenticated',
      () {
        var builderInvocations = 0;
        final testProtectedDef = AppRouteDefinition(
          access: AppRouteAccess.authenticated,
          builder: (settings, coordinator) {
            builderInvocations++;
            return MaterialPageRoute<void>(
              builder: (_) => const SizedBox.shrink(),
              settings: settings,
            );
          },
        );

        final route = AppRoutes.evaluateAndBuildRoute(
          testProtectedDef,
          const RouteSettings(name: '/test-protected'),
          authStatus: AuthSessionStatus.authenticated,
        );

        expect(route, isNotNull);
        expect(builderInvocations, 1);
      },
    );
  });
}
