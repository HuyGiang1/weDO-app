import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/realtime/realtime_binding.dart';
import 'package:mobile/core/realtime/realtime_sync.dart';
import 'package:mobile/features/chat/data/chat_realtime_client.dart';
import 'package:mobile/features/calendar/data/calendar_api.dart';
import 'package:mobile/features/calendar/data/calendar_repository.dart';
import 'package:mobile/features/calendar/presentation/calendar_screen.dart';
import 'package:mobile/features/groups/data/group_api.dart';
import 'package:mobile/features/groups/data/group_repository.dart';

void main() {
  for (final eventType in ['GROUP_MEMBERSHIP_CHANGED','CALENDAR_ACCESS_CHANGED']) { testWidgets('membership invalidation clears Calendar when lookup fails $eventType', (tester) async {
    final adapter=_CalendarAdapter();
    final dio=Dio(BaseOptions(baseUrl:'https://test'))..httpClientAdapter=adapter;
    final sync=RealtimeSync(const NoopChatRealtimeClient());
    await tester.pumpWidget(RealtimeHost(sync:sync,child:MaterialApp(home:CalendarScreen(repository:CalendarRepository(CalendarApi(dio)),groups:GroupRepository(api:GroupApi(dio)),onOpenActivity:(_){},onGroups:(){},onChat:(){},onProfile:(){}))));
    await tester.pumpAndSettle();expect(find.text('Sample event'),findsOneWidget);
    adapter.offline=true;
    sync.accept({'type':'DOMAIN_CHANGED','eventId':'membership','eventType':eventType,'scope':'user:me','aggregateId':'me'});
    await tester.pump(const Duration(milliseconds:100));await tester.pumpAndSettle();expect(find.text('Sample event'),findsNothing);
    await tester.pumpWidget(const SizedBox());await tester.runAsync(sync.dispose);
  });
  }

  testWidgets('membership resync clears a removed selected group before rebuilding dropdown', (tester) async {
    final adapter = _CalendarAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://test'))..httpClientAdapter = adapter;
    final sync = RealtimeSync(const NoopChatRealtimeClient());
    await tester.pumpWidget(RealtimeHost(sync: sync, child: MaterialApp(home: CalendarScreen(
      repository: CalendarRepository(CalendarApi(dio)),
      groups: GroupRepository(api: GroupApi(dio)), onOpenActivity: (_) {},
      onGroups: () {}, onChat: () {}, onProfile: () {},
    ))));
    await tester.pumpAndSettle();
    await _select(tester, 'calendar_group_filter', 'Group One');
    expect(adapter.calendarQueries.last['groupId'], 'group-1');
    adapter.groupsRemoved = true;
    sync.accept({'type': 'DOMAIN_CHANGED', 'eventId': 'removed',
      'eventType': 'GROUP_MEMBERSHIP_CHANGED', 'scope': 'user:me', 'aggregateId': 'me'});
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Tất cả nhóm'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(adapter.calendarQueries.last, isNot(contains('groupId')));
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(sync.dispose);
  });
  testWidgets('calendar filters compose, clear independently, and reset', (
    tester,
  ) async {
    final adapter = _CalendarAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://test'))
      ..httpClientAdapter = adapter;
    String? openedId;
    await tester.pumpWidget(
      MaterialApp(
        home: CalendarScreen(
          repository: CalendarRepository(CalendarApi(dio)),
          groups: GroupRepository(api: GroupApi(dio)),
          onOpenActivity: (id) => openedId = id,
          onGroups: () {},
          onChat: () {},
          onProfile: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sample event'), findsOneWidget);
    expect(find.byTooltip('Tháng trước'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.view_agenda_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Sample event'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.calendar_view_month));
    await tester.pumpAndSettle();
    expect(adapter.calendarQueries.last, isNot(contains('groupId')));
    expect(adapter.calendarQueries.last, isNot(contains('rsvp')));
    expect(adapter.calendarQueries.last, isNot(contains('status')));

    await _select(tester, 'calendar_group_filter', 'Group One');
    expect(adapter.calendarQueries.last['groupId'], 'group-1');
    expect(adapter.calendarQueries.last, isNot(contains('rsvp')));
    expect(adapter.calendarQueries.last, isNot(contains('status')));

    await _select(tester, 'calendar_rsvp_filter', 'Tham gia');
    expect(adapter.calendarQueries.last['groupId'], 'group-1');
    expect(adapter.calendarQueries.last['rsvp'], 'GOING');
    expect(adapter.calendarQueries.last, isNot(contains('status')));

    await _select(tester, 'calendar_status_filter', 'Đang lên kế hoạch');
    expect(adapter.calendarQueries.last, {
      'from': adapter.calendarQueries.last['from'],
      'to': adapter.calendarQueries.last['to'],
      'groupId': 'group-1',
      'rsvp': 'GOING',
      'status': 'PLANNING',
    });

    await _select(tester, 'calendar_group_filter', 'Group Two');
    expect(adapter.calendarQueries.last['groupId'], 'group-2');
    expect(adapter.calendarQueries.last['rsvp'], 'GOING');
    expect(adapter.calendarQueries.last['status'], 'PLANNING');

    await _select(tester, 'calendar_rsvp_filter', 'Có thể tham gia');
    expect(adapter.calendarQueries.last['groupId'], 'group-2');
    expect(adapter.calendarQueries.last['rsvp'], 'MAYBE');
    expect(adapter.calendarQueries.last['status'], 'PLANNING');

    await _select(tester, 'calendar_status_filter', 'Đã xác nhận');
    expect(adapter.calendarQueries.last['groupId'], 'group-2');
    expect(adapter.calendarQueries.last['rsvp'], 'MAYBE');
    expect(adapter.calendarQueries.last['status'], 'CONFIRMED');
    expect(find.text('Group Two'), findsOneWidget);
    expect(find.text('Có thể tham gia'), findsOneWidget);
    expect(find.text('Đã xác nhận'), findsOneWidget);

    await tester.tap(find.byTooltip('Tháng sau'));
    await tester.pumpAndSettle();
    expect(adapter.calendarQueries.last['groupId'], 'group-2');
    expect(adapter.calendarQueries.last['rsvp'], 'MAYBE');
    expect(adapter.calendarQueries.last['status'], 'CONFIRMED');

    await _select(tester, 'calendar_rsvp_filter', 'Mọi phản hồi');
    expect(adapter.calendarQueries.last['groupId'], 'group-2');
    expect(adapter.calendarQueries.last['status'], 'CONFIRMED');
    expect(adapter.calendarQueries.last, isNot(contains('rsvp')));

    await tester.tap(find.byKey(const Key('calendar_clear_filters')));
    await tester.pumpAndSettle();
    expect(adapter.calendarQueries.last, {
      'from': adapter.calendarQueries.last['from'],
      'to': adapter.calendarQueries.last['to'],
    });
    expect(find.text('Tất cả nhóm'), findsOneWidget);
    expect(find.text('Mọi phản hồi'), findsOneWidget);
    expect(find.text('Mọi trạng thái'), findsOneWidget);
    expect(find.byKey(const Key('calendar_clear_filters')), findsNothing);

    await tester.tap(find.byIcon(Icons.view_agenda_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar_activity_activity-1')));
    expect(openedId, 'activity-1');
  });
}

Future<void> _select(WidgetTester tester, String key, String option) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

class _CalendarAdapter implements HttpClientAdapter {
  final List<Map<String, dynamic>> calendarQueries = [];
  bool groupsRemoved = false;
  bool offline = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (offline) return ResponseBody.fromString('{}',503);
    final now = DateTime.now();
    final sampleStartAt = DateTime(now.year, now.month, now.day, 12);
    final isCalendar = options.path == '/api/v1/calendar/activities';
    if (isCalendar) {
      calendarQueries.add(Map<String, dynamic>.from(options.queryParameters));
    }
    final body = isCalendar
        ? [
            {
              'id': 'activity-1',
              'groupId': 'group-1',
              'groupName': 'Group',
              'title': 'Sample event',
              'status': 'CONFIRMED',
              'startAt': sampleStartAt.toUtc().toIso8601String(),
              'endAt': null,
              'timezone': 'Asia/Ho_Chi_Minh',
              'locationName': null,
              'goingCount': 1,
              'waitlistCount': 0,
              'callerRsvpStatus': 'GOING',
              'reminderEnabled': false,
              'reminderAt': null,
            },
          ]
        : {
            'items': groupsRemoved ? [] : [
              {
                'id': 'group-1',
                'name': 'Group One',
                'avatarStorageKey': null,
                'status': 'ACTIVE',
                'callerRole': 'OWNER',
                'updatedAt': now.toUtc().toIso8601String(),
              },
              {
                'id': 'group-2',
                'name': 'Group Two',
                'avatarStorageKey': null,
                'status': 'ACTIVE',
                'callerRole': 'OWNER',
                'updatedAt': now.toUtc().toIso8601String(),
              },
            ],
            'page': 0,
            'size': 100,
            'totalElements': 0,
            'totalPages': 0,
            'hasNext': false,
          };
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
