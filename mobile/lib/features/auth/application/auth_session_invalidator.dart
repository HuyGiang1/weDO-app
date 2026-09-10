import '../../../core/auth/session_invalidation_outcome.dart';
import '../data/auth_failure.dart';
import '../data/auth_repository.dart';
import 'auth_session_controller.dart';

/// Orchestrates generation-aware session invalidation when definitive refresh
/// failures or 401 AUTH_TOKEN_INVALID errors occur.
class AuthSessionInvalidator {
  final AuthRepository repository;
  final AuthSessionController sessionController;

  const AuthSessionInvalidator({
    required this.repository,
    required this.sessionController,
  });

  /// Evaluates whether a refresh failure is definitive and requires
  /// local session invalidation.
  ///
  /// Uses an explicit allow-list. Any new or unrecognized failure type
  /// fails closed and defaults to non-destructive (false).
  static bool isDefinitiveRefreshFailure(AuthFailure failure) {
    return switch (failure.type) {
      AuthFailureType.refreshTokenInvalid ||
      AuthFailureType.noRefreshableSession ||
      AuthFailureType.refreshSessionUnrecoverable ||
      AuthFailureType.accountSuspended ||
      AuthFailureType.accountDeactivated ||
      AuthFailureType.emailNotVerified =>
        true,
      _ => false,
    };
  }

  /// Handles refresh failure with explicit allow-list classification and
  /// generation-aware invalidation.
  Future<void> handleRefreshFailure({
    required AuthFailure failure,
    required int expectedRevision,
  }) async {
    if (!isDefinitiveRefreshFailure(failure)) {
      return;
    }

    await _invalidateSession(expectedRevision: expectedRevision);
  }

  /// Handles 401 AUTH_TOKEN_INVALID for a protected request generation.
  Future<void> handleAccessTokenInvalid({
    required int expectedRevision,
  }) async {
    await _invalidateSession(expectedRevision: expectedRevision);
  }

  Future<void> _invalidateSession({required int expectedRevision}) async {
    final outcome = await repository.invalidateLocalSession(
      expectedRevision: expectedRevision,
    );

    switch (outcome) {
      case SessionInvalidationSuperseded():
        return;
      case SessionInvalidationApplied(:final transition):
        sessionController.markUnauthenticatedIfRevision(transition.toRevision);
    }
  }
}
