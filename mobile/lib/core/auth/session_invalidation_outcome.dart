import 'session_revision.dart';

/// Explicit outcome of a generation-aware local session invalidation.
sealed class SessionInvalidationOutcome {
  const SessionInvalidationOutcome();
}

/// The invalidation was superseded because the session revision changed
/// before or during invalidation (e.g. Account B logged in or user logged out).
final class SessionInvalidationSuperseded extends SessionInvalidationOutcome {
  const SessionInvalidationSuperseded();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionInvalidationSuperseded &&
          runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'SessionInvalidationSuperseded()';
}

/// The invalidation was applied to the matching generation.
///
/// Contains the exact [transition] and records whether [durableCredentialsCleared]
/// succeeded. Runtime memory is always cleared regardless of durable storage status.
final class SessionInvalidationApplied extends SessionInvalidationOutcome {
  final SessionRevisionTransition transition;
  final bool durableCredentialsCleared;

  const SessionInvalidationApplied({
    required this.transition,
    required this.durableCredentialsCleared,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionInvalidationApplied &&
          runtimeType == other.runtimeType &&
          transition == other.transition &&
          durableCredentialsCleared == other.durableCredentialsCleared;

  @override
  int get hashCode => Object.hash(transition, durableCredentialsCleared);

  @override
  String toString() =>
      'SessionInvalidationApplied(transition: $transition, durableCredentialsCleared: $durableCredentialsCleared)';
}
