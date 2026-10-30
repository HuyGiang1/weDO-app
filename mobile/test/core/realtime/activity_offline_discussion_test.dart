import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/core/realtime/realtime_binding.dart';
import 'package:mobile/core/realtime/realtime_sync.dart';
import 'package:mobile/features/activity/application/activity_controllers.dart';
import 'package:mobile/features/activity/data/activity_failure.dart';
import 'package:mobile/features/activity/data/activity_models.dart';
import 'package:mobile/features/activity/presentation/screens/activity_runtime_screens.dart';
import 'package:mobile/features/chat/data/chat_realtime_client.dart';
import 'package:mobile/features/discussion/data/discussion_api.dart';
import 'package:mobile/features/discussion/data/discussion_models.dart';
import 'package:mobile/features/discussion/data/discussion_repository.dart';
import 'package:mobile/features/discussion/presentation/widgets/activity_discussion_section.dart';

import '../../features/activity/application/activity_controllers_test.dart'
    show FakeActivityRepository;

const _offline = ActivityException(
  ActivityFailure(ActivityFailureType.network),
);

void main() {
  late _Activity repository;
  late _Discussion discussion;
  late ActivityDetailController controller;
  late RealtimeSync sync;
  Future<void> mount(WidgetTester tester, {bool offline = false}) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1800));
    repository = _Activity()..failure = offline ? _offline : null;
    discussion = _Discussion();
    controller = ActivityDetailController(repository);
    sync = RealtimeSync(const NoopChatRealtimeClient());
    await tester.pumpWidget(
      RealtimeHost(
        sync: sync,
        child: MaterialApp(
          home: ActivityDetailRuntimeScreen(
            activityId: 'a',
            controller: controller,
            discussion: ActivityDiscussionSection(
              activityId: 'a',
              repository: discussion,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await tester.runAsync(sync.dispose);
      await tester.binding.setSurfaceSize(null);
    });
  }

  Future<void> resync(WidgetTester tester) async {
    sync.resync();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'loaded Discussion stays mounted and visible during parent offline; ACK obtains current data',
    (tester) async {
      await mount(tester);
      await tester.ensureVisible(find.byType(ActivityDiscussionSection));
      final section = tester.state(find.byType(ActivityDiscussionSection));
      expect(find.text('Cached comment'), findsOneWidget);
      repository.failure = _offline;
      discussion.offline = true;
      await resync(tester);
      expect(
        tester.state(find.byType(ActivityDiscussionSection)),
        same(section),
      );
      expect(find.text('Cached comment'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('activity-offline-state')),
        findsOneWidget,
      );
      expect(controller.value.failure?.type, ActivityFailureType.network);
      expect(controller.value.detail, isNotNull);
      expect(find.text('Chưa có bình luận nào.'), findsNothing);
      expect(tester.takeException(), isNull);
      repository.failure = null;
      discussion.offline = false;
      discussion.content = 'Current comment';
      sync.accept({'type': 'SCOPE_SUBSCRIBED', 'scope': 'activity:a'});
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(
        tester.state(find.byType(ActivityDiscussionSection)),
        same(section),
      );
      expect(find.text('Current comment'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('activity-offline-state')),
        findsNothing,
      );
    },
  );
  testWidgets(
    'initial offline terminates loading and does not claim an empty Discussion',
    (tester) async {
      await mount(tester, offline: true);
      expect(find.textContaining('Không thể kết nối'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(ActivityDiscussionSection), findsNothing);
      expect(find.text('Chưa có bình luận nào.'), findsNothing);
      repository.failure = null;
      await resync(tester);
      expect(find.byType(ActivityDiscussionSection), findsOneWidget);
      expect(find.text('Cached comment'), findsOneWidget);
    },
  );
  for (final denied in [
    ActivityFailureType.permission,
    ActivityFailureType.unauthorized,
    ActivityFailureType.notFound,
  ]) {
    testWidgets('$denied clears parent and protected Discussion', (
      tester,
    ) async {
      await mount(tester);
      repository.failure = ActivityException(ActivityFailure(denied));
      await resync(tester);
      expect(find.text('Cached comment'), findsNothing);
      expect(find.byType(ActivityDiscussionSection), findsNothing);
      expect(controller.value.detail, isNull);
      expect(controller.value.participants, isEmpty);
      expect(
        find.textContaining(
          denied == ActivityFailureType.unauthorized ? 'đăng nhập' : 'quyền',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'scope revocation clears mounted Discussion before REST and rejects pending response',
    (tester) async {
      await mount(tester);
      final old = Completer<ActivityDetail>();
      repository.pending = old.future;
      final request = controller.resync('a');
      sync.accept({'type': 'SCOPE_REVOKED', 'scope': 'activity:a'});
      await tester.pump();
      expect(find.text('Cached comment'), findsNothing);
      expect(controller.value.detail, isNull);
      old.complete(repository.current);
      await request;
      expect(controller.value.detail, isNull);
      // Dispose cancels queued binding timer before any further REST attempt.
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'HTTP auth status takes priority; timeout/server failures are transient',
    () {
      for (final code in [401, 403, 404]) {
        expect(
          ActivityFailure.fromApi(
            ApiException(
              statusCode: code,
              transportFailure: ApiTransportFailure.network,
            ),
          ).type,
          code == 401
              ? ActivityFailureType.unauthorized
              : code == 403
              ? ActivityFailureType.permission
              : ActivityFailureType.notFound,
        );
      }
      expect(
        ActivityFailure.fromApi(
          const ApiException(transportFailure: ApiTransportFailure.timeout),
        ).type,
        ActivityFailureType.network,
      );
      expect(
        ActivityFailure.fromApi(const ApiException(statusCode: 503)).type,
        ActivityFailureType.network,
      );
    },
  );
  testWidgets(
    'Activity programming failure is reported instead of being swallowed by binding',
    (tester) async {
      await mount(tester);
      repository.unexpected = StateError('invalid projection');
      await resync(tester);
      expect(tester.takeException(), isA<StateError>());
      expect(controller.value.detail, isNull);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );
}

class _Activity extends FakeActivityRepository {
  Future<ActivityDetail>? pending;
  Object? unexpected;
  @override
  Future<ActivityDetail> detail(String id) {
    if (unexpected != null) return Future.error(unexpected!);
    return pending ?? super.detail(id);
  }
}

class _Discussion extends DiscussionRepository {
  _Discussion() : super(DiscussionApi(Dio()));
  bool offline = false;
  String content = 'Cached comment';
  @override
  Future<ActivityDiscussion> list(String id) async {
    if (offline) {
      throw const ApiException(transportFailure: ApiTransportFailure.network);
    }
    return ActivityDiscussion.fromJson({
      'permissions': {'readOnly': true},
      'comments': [
        {
          'id': 'comment',
          'activityId': id,
          'authorId': 'qa',
          'content': content,
          'createdAt': '2026-10-21T10:00:00Z',
        },
      ],
    });
  }
}
