import 'package:flutter/foundation.dart';

import '../../../core/network/access_token_holder.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/auth/session_invalidation_outcome.dart';
import '../data/auth_repository.dart';

enum AuthSessionStatus {
  restoring,
  unauthenticated,
  authenticated,
}

/// Owns global authenticated-session status without holding raw token strings.
class AuthSessionController extends ValueNotifier<AuthSessionStatus> {
  final SecureStorageService storage;
  final AccessTokenHolder accessTokenHolder;
  final AuthRepository repository;

  AuthSessionController({
    required this.storage,
    required this.accessTokenHolder,
    required this.repository,
    AuthSessionStatus initialStatus = AuthSessionStatus.restoring,
  }) : super(initialStatus);

  AuthSessionStatus get status => value;
  bool get isAuthenticated => value == AuthSessionStatus.authenticated;
  bool get isRestoring => value == AuthSessionStatus.restoring;

  /// Restores session state from durable storage on application bootstrap.
  ///
  /// Lazy validation: If both tokens are present, populates [AccessTokenHolder]
  /// and sets status to [AuthSessionStatus.authenticated] without network calls.
  /// Any token expiration is resolved on the first protected request.
  Future<AuthSessionStatus> restoreSession() async {
    value = AuthSessionStatus.restoring;

    String? accessToken;
    String? refreshToken;

    try {
      accessToken = await storage.readAccessToken();
      refreshToken = await storage.readRefreshToken();
    } catch (_) {
      // Storage read failure does not prove persisted tokens are invalid;
      // Keychain/Keystore may be temporarily locked. Clear RAM only.
      accessTokenHolder.clearAccessToken();
      value = AuthSessionStatus.unauthenticated;
      return value;
    }

    final hasAccess = accessToken != null && accessToken.trim().isNotEmpty;
    final hasRefresh = refreshToken != null && refreshToken.trim().isNotEmpty;

    if (hasAccess && hasRefresh) {
      accessTokenHolder.setAccessToken(accessToken);
      value = AuthSessionStatus.authenticated;
      return value;
    }

    if (!hasAccess && !hasRefresh) {
      accessTokenHolder.clearAccessToken();
      value = AuthSessionStatus.unauthenticated;
      return value;
    }

    // Partial session (access-only or refresh-only): cannot rotate safely.
    // Evict corrupt session using the established local boundary.
    try {
      await repository.clearLocalSession();
    } catch (_) {
      accessTokenHolder.clearAccessToken();
    } finally {
      value = AuthSessionStatus.unauthenticated;
    }

    return value;
  }

  void markAuthenticated() {
    value = AuthSessionStatus.authenticated;
  }

  void markUnauthenticated() {
    value = AuthSessionStatus.unauthenticated;
  }

  /// Sets session status to [AuthSessionStatus.unauthenticated] if and only if
  /// [accessTokenHolder.revision] matches [expectedRevision].
  ///
  /// Synchronous guard against TOCTOU race where a newer login or session change
  /// occurred between invalidation and status update.
  bool markUnauthenticatedIfRevision(int expectedRevision) {
    if (accessTokenHolder.revision != expectedRevision) {
      return false;
    }
    value = AuthSessionStatus.unauthenticated;
    return true;
  }

  Future<bool> endSessionAfterPasswordChange() async {
    final outcome = await repository.invalidateLocalSession(expectedRevision: accessTokenHolder.revision);
    switch (outcome) {
      case SessionInvalidationSuperseded(): return false;
      case SessionInvalidationApplied(:final transition): return markUnauthenticatedIfRevision(transition.toRevision);
    }
  }
}
