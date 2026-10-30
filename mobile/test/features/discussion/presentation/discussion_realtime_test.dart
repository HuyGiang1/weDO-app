import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/core/realtime/realtime_binding.dart';
import 'package:mobile/core/realtime/realtime_sync.dart';
import 'package:mobile/features/chat/data/chat_realtime_client.dart';
import 'package:mobile/features/discussion/data/discussion_api.dart';
import 'package:mobile/features/discussion/data/discussion_models.dart';
import 'package:mobile/features/discussion/data/discussion_repository.dart';
import 'package:mobile/features/discussion/presentation/widgets/activity_discussion_section.dart';

const _network = ApiException(transportFailure: ApiTransportFailure.network);

void main() {
  late _Repository repository;
  late RealtimeSync sync;
  Future<void> mount(WidgetTester tester) async {
    repository = _Repository();
    sync = RealtimeSync(const NoopChatRealtimeClient());
    await tester.pumpWidget(
      RealtimeHost(
        sync: sync,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ActivityDiscussionSection(
                activityId: 'a',
                repository: repository,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final mountedSync = sync;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(mountedSync.dispose);
    });
  }

  Future<void> invalidate(WidgetTester tester) async {
    sync.accept({
      'type': 'DOMAIN_CHANGED',
      'eventId': 'event-${repository.calls}',
      'eventType': 'DISCUSSION_COMMENT_ADDED',
      'scope': 'activity:a',
      'aggregateId': 'a',
    });
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  dynamic state(WidgetTester tester) =>
      tester.state(find.byType(ActivityDiscussionSection));

  testWidgets(
    'scope revocation clears cached comments immediately and invalidates late success',
    (tester) async {
      await mount(tester);
      final old = Completer<ActivityDiscussion>();
      repository.load = () => old.future;
      final Future<void> pending = state(tester).reloadRealtime();
      sync.accept({'type': 'SCOPE_REVOKED', 'scope': 'activity:a'});
      await tester.pump();
      expect(find.text('Original'), findsNothing);
      expect(find.textContaining('quyền'), findsOneWidget);
      old.complete(_data('Unauthorized old result'));
      await pending;
      repository.load = () async => throw _network;
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.text('Unauthorized old result'), findsNothing);
      expect(find.textContaining('quyền'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('A targeted invalidation updates visible Discussion', (
    tester,
  ) async {
    await mount(tester);
    repository.load = () async => _data('Current');
    await invalidate(tester);
    expect(find.text('Current'), findsOneWidget);
    expect(find.text('Original'), findsNothing);
    expect(repository.calls, 2);
  });
  testWidgets(
    'B C D network failure retains data without uncaught error; scope ACK resync recovers',
    (tester) async {
      await mount(tester);
      repository.load = () async => throw _network;
      await invalidate(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Original'), findsOneWidget);
      expect(find.text('Chưa có bình luận nào.'), findsNothing);
      expect(find.textContaining('Không thể cập nhật'), findsOneWidget);
      repository.load = () async => _data('Recovered');
      sync.accept({'type': 'SCOPE_SUBSCRIBED', 'scope': 'activity:a'});
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.text('Recovered'), findsOneWidget);
      expect(find.textContaining('Không thể cập nhật'), findsNothing);
      final calls = repository.calls;
      await tester.pump(const Duration(seconds: 10));
      expect(repository.calls, calls); // No timer/retry loop.
    },
  );
  testWidgets('E disposed state ignores late response and late API error', (
    tester,
  ) async {
    for (final fail in [false, true]) {
      await mount(tester);
      final pending = Completer<ActivityDiscussion>();
      repository.load = () => pending.future;
      final Future<void> request = state(tester).reloadRealtime();
      await tester.pumpWidget(const SizedBox());
      if (fail) {
        pending.completeError(_network);
      } else {
        pending.complete(_data('Late'));
      }
      await request;
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });
  for (final fail in [false, true]) {
    testWidgets(
      'F stale ${fail ? 'failure' : 'success'} cannot replace newer success',
      (tester) async {
        await mount(tester);
        final pending = Completer<ActivityDiscussion>();
        repository.load = () => pending.future;
        final Future<void> old = state(tester).reloadRealtime();
        repository.load = () async => _data('Newer');
        await state(tester).reloadRealtime();
        if (fail) {
          pending.completeError(_network);
        } else {
          pending.complete(_data('Older'));
        }
        await old;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Newer'), findsOneWidget);
        expect(find.text('Older'), findsNothing);
        expect(find.textContaining('Không thể cập nhật'), findsNothing);
      },
    );
  }
  for (final status in [401, 403]) {
    testWidgets(
      '$status is an authorization failure, not stale network success',
      (tester) async {
        await mount(tester);
        repository.load = () async => throw ApiException(statusCode: status);
        await invalidate(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('Original'), findsNothing);
        expect(
          find.textContaining(status == 401 ? 'đăng nhập' : 'quyền'),
          findsOneWidget,
        );
        expect(find.textContaining('Không thể cập nhật'), findsNothing);
      },
    );
  }
  for (final failure in [
    const ApiException(transportFailure: ApiTransportFailure.timeout),
    const ApiException(statusCode: 503),
  ]) {
    testWidgets(
      'timeout/server ${failure.statusCode} failure preserves data; resync recovers',
      (tester) async {
        await mount(tester);
        repository.load = () async => throw failure;
        await invalidate(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('Original'), findsOneWidget);
        repository.load = () async => _data('Resynced');
        sync.resync();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        expect(find.text('Resynced'), findsOneWidget);
      },
    );
  }
  testWidgets(
    'programming errors are reported, not disguised as network failure',
    (tester) async {
      await mount(tester);
      repository.load = () async => throw StateError('bad projection');
      await invalidate(tester);
      expect(tester.takeException(), isA<StateError>());
      expect(find.textContaining('Không thể cập nhật'), findsNothing);
    },
  );
}

class _Repository extends DiscussionRepository {
  _Repository() : super(DiscussionApi(Dio()));
  int calls = 0;
  Future<ActivityDiscussion> Function() load = () async => _data('Original');
  @override
  Future<ActivityDiscussion> list(String id) {
    calls++;
    return load();
  }
}

ActivityDiscussion _data(String text) => ActivityDiscussion.fromJson({
  'permissions': {'canComment': false, 'readOnly': true},
  'comments': [
    {
      'id': 'comment',
      'activityId': 'a',
      'authorId': 'qa',
      'content': text,
      'createdAt': '2026-10-21T10:00:00Z',
    },
  ],
});
