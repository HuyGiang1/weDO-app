final class SessionRevisionTransition {
  final int fromRevision;
  final int toRevision;

  const SessionRevisionTransition({
    required this.fromRevision,
    required this.toRevision,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionRevisionTransition &&
          runtimeType == other.runtimeType &&
          fromRevision == other.fromRevision &&
          toRevision == other.toRevision;

  @override
  int get hashCode => Object.hash(fromRevision, toRevision);

  @override
  String toString() =>
      'SessionRevisionTransition($fromRevision -> $toRevision)';
}
