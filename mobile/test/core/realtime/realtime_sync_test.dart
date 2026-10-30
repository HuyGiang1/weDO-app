import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/realtime/realtime_sync.dart';
import 'package:mobile/features/chat/data/chat_realtime_client.dart';

class _Socket implements ChatRealtimeSocket {
  final frames = StreamController<dynamic>.broadcast();
  final sent = <Map<String, dynamic>>[];
  @override Stream<dynamic> get stream => frames.stream;
  @override void add(String raw) => sent.add(jsonDecode(raw));
  @override Future<void> close() => frames.close();
}

Map<String, dynamic> _event(String id, {String scope = 'activity:a', String type = 'ACTIVITY_RSVP_CHANGED', int? version}) => {
  'type': 'DOMAIN_CHANGED', 'eventId': id, 'eventType': type,
  'aggregateId': 'a', 'scope': scope, 'groupId': 'g',
  'version': ?version,
};

void main() {
  testWidgets('reachable unauthorized handshake requests one REST resync per outage, not a retry storm', (tester) async {
    final socket = _Socket();
    var openings = 0, resyncs = 0;
    final client = WebSocketChatRealtimeClient(
      baseUrl: 'http://qa.invalid:8080', accessTokenProvider: () => 'fixture',
      initialReconnectDelay: const Duration(milliseconds: 200),
      connector: (_, _) async {
        if (++openings == 1) return socket;
        throw const WebSocketException('Fixture denied', 401);
      },
    );
    final sync = RealtimeSync(client);
    sync.watch('group:g', 'EXPENSE_', () => resyncs++);
    await client.connect(); await tester.pump();
    await socket.close(); await tester.pump();
    expect(resyncs, 1); // Original loss resync may fail offline.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(resyncs, 2); // Reachable 401, existing REST auth policy decides.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 800));
    expect(openings, 4);
    expect(resyncs, 2); // No REST refresh on every denied handshake.
    client.dispose(); await tester.runAsync(sync.dispose); await tester.pump();
  });

  testWidgets('late unauthorized old handshake cannot resync a new session', (tester) async {
    final delayed = Completer<ChatRealtimeSocket>();
    final socket = _Socket();
    var attempts = 0, resyncs = 0;
    final client = WebSocketChatRealtimeClient(
      baseUrl: 'http://qa.invalid:8080', accessTokenProvider: () => 'fixture',
      connector: (_, _) => ++attempts == 1 ? delayed.future : Future.value(socket),
    );
    final sync = RealtimeSync(client);
    sync.watch('group:g', 'EXPENSE_', () => resyncs++);
    final old = client.connect();
    await client.disconnect(); await client.connect();
    delayed.completeError(const WebSocketException('Old fixture denied', 401));
    await old; await tester.pump();
    expect(resyncs, 0);
    expect(client.currentState.name, 'connected');
    client.dispose(); await tester.runAsync(sync.dispose); await tester.pump();
  });

  test('RSVP socket frame routes once and duplicate eventId cannot refetch twice', () async {
    final socket = _Socket();
    final client = WebSocketChatRealtimeClient(
      baseUrl: 'http://localhost:8080', accessTokenProvider: () => 'fixture',
      connector: (_, headers) async => socket,
    );
    final sync = RealtimeSync(client);
    var refetches = 0;
    sync.watch('activity:a', 'ACTIVITY_', () => refetches++);
    await client.connect();
    final raw = jsonEncode(_event('rsvp-one'));
    socket.frames.add(raw);
    socket.frames.add(raw);
    await Future<void>.delayed(Duration.zero);
    expect(refetches, 1);
    await sync.dispose();
    client.dispose();
  });
  test('membership restoration retries denied desired scopes without reconnecting', () async {
    final socket = _Socket();
    final client = WebSocketChatRealtimeClient(
      baseUrl: 'http://localhost:8080', accessTokenProvider: () => 'fixture',
      connector: (_, headers) async => socket,
    );
    final sync = RealtimeSync(client);
    sync.watch('activity:a', 'TASK_', () {});
    await client.connect();
    socket.frames.add(jsonEncode({'type': 'SCOPE_REVOKED', 'scope': 'activity:a'}));
    await Future<void>.delayed(Duration.zero);
    final before = socket.sent.length;
    sync.accept(_event('rejoined', scope: 'user:me', type: 'GROUP_MEMBERSHIP_CHANGED'));
    expect(socket.sent.length, before + 1);
    expect(socket.sent.last, {'type': 'SUBSCRIBE_SCOPE', 'scope': 'activity:a'});
    expect(client.currentState.name, 'connected');
    await sync.dispose();
    client.dispose();
  });
  test('Activity lifecycle and RSVP invalidate dependent permissions on matching Task resources', () async {
    final sync = RealtimeSync(const NoopChatRealtimeClient());
    var task = 0, discussion = 0;
    sync.watch('activity:a', 'TASK_', () => task++, aggregateId: 'task-1');
    sync.watch('activity:a', 'DISCUSSION_', () => discussion++);
    sync.accept(_event('rsvp'));
    expect([task, discussion], [1, 0]);
    sync.accept(_event('completed', type: 'ACTIVITY_UPDATED'));
    expect([task, discussion], [2, 1]);
    await sync.dispose();
  });
  test('late handshake from previous auth generation cannot replace the new socket', () async {
    final oldHandshake = Completer<ChatRealtimeSocket>();
    final old = _Socket(), current = _Socket();
    var attempts = 0;
    final client = WebSocketChatRealtimeClient(
      baseUrl: 'http://localhost:8080', accessTokenProvider: () => 'fixture',
      connector: (_, headers) async => ++attempts == 1 ? oldHandshake.future : current,
    );
    final opening = client.connect();
    await client.disconnect();
    await client.connect();
    oldHandshake.complete(old);
    await opening;
    client.subscribeScope('user:self');
    expect(current.sent.last['scope'], 'user:self');
    expect(old.sent, isEmpty);
    expect(old.frames.isClosed, isTrue);
    client.dispose();
  });

  test('routes only matching resources, deduplicates and ignores stale explicit versions', () async {
    final sync = RealtimeSync(const NoopChatRealtimeClient());
    var activity = 0, task = 0, other = 0;
    sync.watch('activity:a', 'ACTIVITY_', () => activity++);
    sync.watch('activity:a', 'TASK_', () => task++);
    sync.watch('activity:b', '', () => other++);
    sync.accept(_event('one', version: 2, type: 'ACTIVITY_CREATED'));
    sync.accept(_event('one', version: 2, type: 'ACTIVITY_CREATED'));
    sync.accept(_event('old', version: 1, type: 'ACTIVITY_CREATED'));
    sync.accept(_event('next', version: 3, type: 'ACTIVITY_CREATED'));
    expect([activity, task, other], [2, 0, 0]);
    await sync.dispose();
  });

  test('unversioned reordered hints still refetch, group parents route and revocation resyncs', () async {
    final sync = RealtimeSync(const NoopChatRealtimeClient());
    var count = 0;
    final stop = sync.watch('group:g', 'ACTIVITY_', () => count++);
    sync.accept(_event('later')..['occurredAt'] = '2030-01-02T00:00:00Z');
    sync.accept(_event('earlier')..['occurredAt'] = '2030-01-01T00:00:00Z');
    sync.accept({'type': 'SCOPE_REVOKED', 'scope': 'group:g'});
    expect(count, 3);
    stop();
    sync.resync();
    expect(count, 3);
    await sync.dispose();
  });

  test('self user controls resync and malformed input is ignored', () async {
    final sync = RealtimeSync(const NoopChatRealtimeClient());
    var count = 0;
    sync.watch('user:self', 'NOTIFICATION_', () => count++);
    sync.accept({'type': 'SCOPE_SUBSCRIBED', 'scope': 'user:real-id'});
    sync.accept(_event('read', scope: 'user:real-id', type: 'NOTIFICATION_READ'));
    sync.accept({'type': 'DOMAIN_CHANGED', 'scope': 'user:real-id'});
    expect(count, 2);
    await sync.dispose();
  });

  test('Activity shares one scope, reconnect restores subscription and ACK resyncs', () async {
    final sockets = <_Socket>[];
    final client = WebSocketChatRealtimeClient(
      baseUrl: 'http://localhost:8080', accessTokenProvider: () => 'fixture',
      initialReconnectDelay: const Duration(milliseconds: 200),
      connector: (_, headers) async { final socket = _Socket(); sockets.add(socket); return socket; },
    );
    final sync = RealtimeSync(client);
    var resyncs = 0;
    final first = sync.watch('activity:a', 'ACTIVITY_', () => resyncs++);
    final second = sync.watch('activity:a', 'TASK_', () => resyncs++);
    await client.connect();
    expect(sockets.first.sent.where((frame) => frame['type'] == 'SUBSCRIBE_SCOPE').length, 1);
    sockets.first.frames.add(jsonEncode({'type': 'SCOPE_SUBSCRIBED', 'scope': 'activity:a'}));
    await Future<void>.delayed(Duration.zero);
    expect(resyncs, 2);
    second();
    expect(sockets.first.sent.where((frame) => frame['type'] == 'UNSUBSCRIBE_SCOPE'), isEmpty);
    await sockets.first.close();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(sockets.length, 2);
    expect(sockets.last.sent.single['scope'], 'activity:a');
    sockets.last.frames.add(jsonEncode({'type': 'SCOPE_SUBSCRIBED', 'scope': 'activity:a'}));
    await Future<void>.delayed(Duration.zero);
    expect(resyncs, 4); // One REST recovery on loss, one after authorized re-subscribe.
    first();
    expect(sockets.last.sent.last['type'], 'UNSUBSCRIBE_SCOPE');
    await sync.dispose();
    client.dispose();
  });
}
