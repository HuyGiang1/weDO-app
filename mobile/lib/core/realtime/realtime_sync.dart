import 'dart:async';

import '../../features/chat/data/chat_realtime_client.dart';
import '../../features/chat/data/chat_realtime_event.dart';

/// Small invalidations only; REST remains responsible for viewer permissions.
class RealtimeChange {
  final String eventId, eventType, scope, aggregateId;
  final int? version;
  const RealtimeChange(this.eventId, this.eventType, this.scope, this.aggregateId,
      {this.version});

  static RealtimeChange? parse(Map<String, dynamic> frame) {
    if (frame['type'] != 'DOMAIN_CHANGED') return null;
    final fields = ['eventId', 'eventType', 'scope', 'aggregateId'];
    if (fields.any((key) => frame[key] is! String || (frame[key] as String).isEmpty)) {
      return null;
    }
    return RealtimeChange(frame['eventId'], frame['eventType'], frame['scope'],
        frame['aggregateId'], version: (frame['version'] as num?)?.toInt());
  }
}

/// Owns reference-counted subscriptions and bounded transport deduplication.
/// No navigation, FCM, business policy, timer polling or screen dependencies.
class RealtimeSync {
  final ChatRealtimeClient client;
  final _listeners = <_Watch>{};
  final _seen = <String>{};
  final _versions = <String, int>{};
  late final StreamSubscription<ChatRealtimeEvent> _events;
  late final StreamSubscription<ChatRealtimeConnectionState> _states;
  bool _disposed = false;

  RealtimeSync(this.client) {
    _events = client.events.listen((event) {
      if (event.type == ChatRealtimeEventType.error &&
          event.errorCode == 'WS_HANDSHAKE_UNAUTHORIZED') {
        resync();
      }
      if (event.type == ChatRealtimeEventType.pong) {
        for (final watch in List<_Watch>.of(_listeners)) {
          watch.onReachable?.call();
        }
      }
      final frame = event.domainFrame;
      if (frame != null) accept(frame);
    });
    _states = client.connectionStates.listen((state) {
      // A REST resync also exercises the existing auth refresh interceptor if
      // the cached handshake token expired during a long foreground session.
      if (state == ChatRealtimeConnectionState.reconnecting) resync();
    });
  }

  void Function() watch(String scope, String prefix, void Function() invalidate, {String? aggregateId, void Function(RealtimeChange?)? onChange, void Function()? onAccessLost, void Function()? onReachable}) {
    final watch = _Watch(scope, prefix, invalidate, aggregateId, onChange, onAccessLost, onReachable);
    _listeners.add(watch);
    if (client is ScopedRealtimeClient) {
      (client as ScopedRealtimeClient).subscribeScope(scope);
    }
    return () {
      _listeners.remove(watch);
      if (!_listeners.any((item) => item.scope == scope) && client is ScopedRealtimeClient) {
        (client as ScopedRealtimeClient).unsubscribeScope(scope);
      }
    };
  }

  void accept(Map<String, dynamic> frame) {
    if (_disposed) return;
    final scope = frame['scope'];
    if (scope is! String) return;
    final type = frame['type'];
    final control = type == 'SCOPE_SUBSCRIBED' || type == 'SCOPE_REVOKED' || type == 'SCOPE_DENIED' || type == 'SCOPE_RESYNC';
    final event = RealtimeChange.parse(frame);
    if (!control && event == null) return;
    if (event != null) {
      if (!_seen.add(event.eventId)) return;
      if ((event.eventType == 'GROUP_MEMBERSHIP_CHANGED' || event.eventType == 'GROUP_JOIN_APPROVED') && client is ScopedRealtimeClient) {
        (client as ScopedRealtimeClient).retryDeniedScopes();
      }
      if (_seen.length > 2000) _seen.remove(_seen.first);
      final key = '$scope:${event.aggregateId}';
      final version = event.version;
      if (version != null) {
        if (version <= (_versions[key] ?? -1)) return;
        _versions.remove(key);
        _versions[key] = version;
        if (_versions.length > 2000) _versions.remove(_versions.keys.first);
      }
      // Unversioned invalidations must not be dropped by wall-clock time: two
      // transactions may commit in the opposite order to their timestamps.
    }
    for (final watch in List<_Watch>.of(_listeners)) {
      final matches = watch.scope == scope ||
          (watch.scope == 'user:self' && scope.startsWith('user:')) ||
          (event != null && frame['groupId'] != null && watch.scope == 'group:${frame['groupId']}');
      final dependentPermission = event != null && watch.scope == scope && (
          event.eventType == 'ACTIVITY_UPDATED' ||
          (watch.prefix == 'TASK_' && (event.eventType == 'ACTIVITY_RSVP_CHANGED' || event.eventType == 'ACTIVITY_PARTICIPANTS_CHANGED')));
      if (matches && (control || dependentPermission || (event!.eventType.startsWith(watch.prefix) &&
          (watch.aggregateId == null || watch.aggregateId == event.aggregateId)))) {
        if (type == 'SCOPE_REVOKED' || type == 'SCOPE_DENIED') watch.onAccessLost?.call();
        watch.onChange?.call(event);
        watch.invalidate();
      }
    }
  }

  void resync() {
    if (client is ScopedRealtimeClient) (client as ScopedRealtimeClient).retryDeniedScopes();
    for (final watch in List<_Watch>.of(_listeners)) { watch.onChange?.call(null); watch.invalidate(); }
  }

  void reset() { _seen.clear(); _versions.clear(); }

  Future<void> dispose() async {
    _disposed = true;
    await _events.cancel();
    await _states.cancel();
    for (final scope in _listeners.map((item) => item.scope).toSet()) {
      if (client is ScopedRealtimeClient) (client as ScopedRealtimeClient).unsubscribeScope(scope);
    }
    _listeners.clear();
  }
}

class _Watch {
  final String scope, prefix;
  final String? aggregateId;
  final void Function(RealtimeChange?)? onChange;
  final void Function()? onAccessLost;
  final void Function()? onReachable;
  final void Function() invalidate;
  _Watch(this.scope, this.prefix, this.invalidate, this.aggregateId, this.onChange, this.onAccessLost, this.onReachable);
}
