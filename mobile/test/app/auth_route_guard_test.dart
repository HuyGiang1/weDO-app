import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/auth_route_guard.dart';
import 'package:mobile/features/auth/application/auth_session_controller.dart';

void main() {
  group('AuthRouteGuard Security Matrix', () {
    group('public route access', () {
      test('public + restoring -> allow', () {
        expect(
          AuthRouteGuard.evaluate(
            access: AppRouteAccess.public,
            authStatus: AuthSessionStatus.restoring,
          ),
          RouteGuardDecision.allow,
        );
        expect(
          AuthRouteGuard.canAccess(
            access: AppRouteAccess.public,
            authStatus: AuthSessionStatus.restoring,
          ),
          isTrue,
        );
      });

      test('public + unauthenticated -> allow', () {
        expect(
          AuthRouteGuard.evaluate(
            access: AppRouteAccess.public,
            authStatus: AuthSessionStatus.unauthenticated,
          ),
          RouteGuardDecision.allow,
        );
        expect(
          AuthRouteGuard.canAccess(
            access: AppRouteAccess.public,
            authStatus: AuthSessionStatus.unauthenticated,
          ),
          isTrue,
        );
      });

      test('public + authenticated -> allow', () {
        expect(
          AuthRouteGuard.evaluate(
            access: AppRouteAccess.public,
            authStatus: AuthSessionStatus.authenticated,
          ),
          RouteGuardDecision.allow,
        );
        expect(
          AuthRouteGuard.canAccess(
            access: AppRouteAccess.public,
            authStatus: AuthSessionStatus.authenticated,
          ),
          isTrue,
        );
      });
    });

    group('authenticated-required route access', () {
      test('authenticated + restoring -> denyRestoring', () {
        expect(
          AuthRouteGuard.evaluate(
            access: AppRouteAccess.authenticated,
            authStatus: AuthSessionStatus.restoring,
          ),
          RouteGuardDecision.denyRestoring,
        );
        expect(
          AuthRouteGuard.canAccess(
            access: AppRouteAccess.authenticated,
            authStatus: AuthSessionStatus.restoring,
          ),
          isFalse,
        );
      });

      test('authenticated + unauthenticated -> denyUnauthenticated', () {
        expect(
          AuthRouteGuard.evaluate(
            access: AppRouteAccess.authenticated,
            authStatus: AuthSessionStatus.unauthenticated,
          ),
          RouteGuardDecision.denyUnauthenticated,
        );
        expect(
          AuthRouteGuard.canAccess(
            access: AppRouteAccess.authenticated,
            authStatus: AuthSessionStatus.unauthenticated,
          ),
          isFalse,
        );
      });

      test('authenticated + authenticated -> allow', () {
        expect(
          AuthRouteGuard.evaluate(
            access: AppRouteAccess.authenticated,
            authStatus: AuthSessionStatus.authenticated,
          ),
          RouteGuardDecision.allow,
        );
        expect(
          AuthRouteGuard.canAccess(
            access: AppRouteAccess.authenticated,
            authStatus: AuthSessionStatus.authenticated,
          ),
          isTrue,
        );
      });
    });
  });
}
