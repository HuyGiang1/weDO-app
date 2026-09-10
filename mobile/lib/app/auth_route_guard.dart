import '../features/auth/application/auth_session_controller.dart';

/// Declares the authorization requirement of a route.
enum AppRouteAccess {
  public,
  authenticated,
}

/// The pure outcome of evaluating a route against the current session status.
enum RouteGuardDecision {
  allow,
  denyUnauthenticated,
  denyRestoring,
}

/// Pure policy evaluator for route access based on session status.
///
/// This evaluator has zero dependencies on Flutter navigation, widgets,
/// networking, or storage credentials.
abstract final class AuthRouteGuard {
  /// Evaluates whether a route with [access] can be navigated to given [authStatus].
  ///
  /// Security matrix:
  /// - [AppRouteAccess.public]:
  ///   - restoring       -> [RouteGuardDecision.allow]
  ///   - unauthenticated -> [RouteGuardDecision.allow]
  ///   - authenticated   -> [RouteGuardDecision.allow]
  /// - [AppRouteAccess.authenticated]:
  ///   - restoring       -> [RouteGuardDecision.denyRestoring]
  ///   - unauthenticated -> [RouteGuardDecision.denyUnauthenticated]
  ///   - authenticated   -> [RouteGuardDecision.allow]
  static RouteGuardDecision evaluate({
    required AppRouteAccess access,
    required AuthSessionStatus authStatus,
  }) {
    return switch (access) {
      AppRouteAccess.public => RouteGuardDecision.allow,
      AppRouteAccess.authenticated => switch (authStatus) {
        AuthSessionStatus.authenticated => RouteGuardDecision.allow,
        AuthSessionStatus.unauthenticated =>
          RouteGuardDecision.denyUnauthenticated,
        AuthSessionStatus.restoring => RouteGuardDecision.denyRestoring,
      },
    };
  }

  /// Convenience helper returning true if and only if [evaluate] returns [RouteGuardDecision.allow].
  static bool canAccess({
    required AppRouteAccess access,
    required AuthSessionStatus authStatus,
  }) {
    return evaluate(access: access, authStatus: authStatus) ==
        RouteGuardDecision.allow;
  }
}
