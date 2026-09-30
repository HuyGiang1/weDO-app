import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/data/calendar_api.dart';
import 'package:mobile/features/calendar/data/calendar_repository.dart';
import 'package:mobile/features/calendar/presentation/activity_reminder_panel.dart';

void main() {
  testWidgets('reminder switch saves offset and uses server response', (
    tester,
  ) async {
    final adapter = _ReminderAdapter();
    final repository = CalendarRepository(
      CalendarApi(
        Dio(BaseOptions(baseUrl: 'https://test'))..httpClientAdapter = adapter,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActivityReminderPanel(
            activityId: 'activity-1',
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Personal reminder'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(adapter.putPayload, {'enabled': true, 'offsetMinutes': 15});
    expect(find.textContaining('2026'), findsOneWidget);
  });
}

class _ReminderAdapter implements HttpClientAdapter {
  Map<String, dynamic>? putPayload;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'PUT') {
      putPayload = Map<String, dynamic>.from(options.data as Map);
    }
    final enabled = options.method == 'PUT';
    return ResponseBody.fromString(
      jsonEncode({
        'activityId': 'activity-1',
        'configured': enabled,
        'enabled': enabled,
        'offsetMinutes': enabled ? 15 : null,
        'remindAt': enabled ? '2026-09-29T12:45:00Z' : null,
        'sentAt': null,
        'canConfigure': true,
        'unavailableReason': null,
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
