import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/poll/data/poll_api.dart';
import 'package:mobile/features/poll/data/poll_repository.dart';
import 'package:mobile/features/poll/presentation/screens/poll_screens.dart';

void main() {
  late _PollScreenAdapter adapter;
  late PollRepository repository;

  setUp(() {
    adapter = _PollScreenAdapter();
    repository = PollRepository(
      PollApi(
        Dio(BaseOptions(baseUrl: 'https://test'))..httpClientAdapter = adapter,
      ),
    );
  });

  testWidgets(
    'P0 rapid vote submits once and disposal ignores late completion',
    (tester) async {
      adapter.voteGate = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: PollDetailScreen(pollId: 'poll-1', repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Park'));
      await tester.pump();
      await tester.tap(find.text('Gửi bình chọn'));
      await tester.pump();
      await tester.tap(find.text('Gửi bình chọn'));
      await tester.pumpAndSettle();
      expect(adapter.requests.where((r) => r.method == 'PUT'), hasLength(1));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Gửi bình chọn'),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
      adapter.voteGate!.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final entry in {
    'POLL_CLOSED': 409,
    'POLL_DEADLINE_PASSED': 409,
    'ACCESS_DENIED': 403,
    'AUTH_REQUIRED': 401,
    'NETWORK': 0,
    'UNAVAILABLE': 503,
  }.entries) {
    testWidgets(
      'P0 rejected ${entry.key} has no phantom vote and meaningful feedback',
      (tester) async {
        adapter.voteFailure = entry.key;
        adapter.voteStatus = entry.value;
        await tester.pumpWidget(
          MaterialApp(
            home: PollDetailScreen(pollId: 'poll-1', repository: repository),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Park'));
        await tester.pump();
        await tester.tap(find.text('Gửi bình chọn'));
        await tester.pumpAndSettle();
        expect(adapter.callerOptionIds, isEmpty);
        expect(find.byType(SnackBar), findsOneWidget);
        if (entry.value == 403) {
          expect(find.text('Where should we meet?'), findsNothing);
        }
        if (entry.key.startsWith('POLL_')) {
          expect(find.text('Bình chọn đã đóng hoặc hết hạn.'), findsOneWidget);
        }
        if (entry.key == 'NETWORK') {
          expect(
            find.textContaining('Bình chọn chưa được xác nhận'),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Create Poll has no multiple-choice or max-selection controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CreatePollScreen(
          activityId: 'activity-1',
          repository: repository,
        ),
      ),
    );

    expect(find.text('Một'), findsNothing);
    expect(find.text('Nhiều'), findsNothing);
    expect(find.text('Giới hạn số lựa chọn'), findsNothing);
    expect(find.text('Tạo bình chọn'), findsNWidgets(2));
    expect(find.text('Hạn bình chọn'), findsOneWidget);
  });

  testWidgets(
    'single-choice voting replaces selection and sends one option id',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PollDetailScreen(pollId: 'poll-1', repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Park'));
      await tester.pump();
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      final submit = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Gửi bình chọn'),
      );
      expect(submit.onPressed, isNotNull);
      expect(submit.style!.foregroundColor!.resolve({}), Colors.white);

      await tester.tap(find.text('Cafe'));
      await tester.pump();
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);

      await tester.tap(find.text('Gửi bình chọn'));
      await tester.pumpAndSettle();

      expect(adapter.votePayload?['optionIds'], ['option-2']);
      expect(adapter.votePayload?['clientRequestId'], isNotEmpty);
      expect(adapter.callerOptionIds, ['option-2']);
    },
  );

  testWidgets(
    'an open immediate-results poll keeps one-option voting available',
    (tester) async {
      adapter.resultsVisible = true;
      adapter.deadlineAt = DateTime.now()
          .add(const Duration(hours: 1))
          .toUtc()
          .toIso8601String();
      await tester.pumpWidget(
        MaterialApp(
          home: PollDetailScreen(pollId: 'poll-1', repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      final submit = find.widgetWithText(FilledButton, 'Gửi bình chọn');
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      expect(find.text('0 phiếu'), findsNWidgets(2));

      await tester.tap(find.text('Cafe'));
      await tester.pump();
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);

      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(adapter.votePayload?['optionIds'], ['option-2']);
      expect(adapter.votePayload?['clientRequestId'], isNotEmpty);
      expect(
        adapter.requests.where((request) => request.method == 'GET').length,
        greaterThanOrEqualTo(2),
      );
      expect(adapter.lastResponseStatus, 200);
      expect(adapter.callerOptionIds, ['option-2']);
    },
  );

  testWidgets('server canVote false does not offer a vote action', (
    tester,
  ) async {
    adapter.canVote = false;
    await tester.pumpWidget(
      MaterialApp(
        home: PollDetailScreen(pollId: 'poll-1', repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gửi bình chọn'), findsNothing);
  });

  testWidgets('closed polls do not offer a vote action', (tester) async {
    adapter.closed = true;
    await tester.pumpWidget(
      MaterialApp(
        home: PollDetailScreen(pollId: 'poll-1', repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gửi bình chọn'), findsNothing);
  });
}

class _PollScreenAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  List<String> callerOptionIds = [];
  Map<String, dynamic>? votePayload;
  bool closed = false;
  bool canVote = true;
  bool resultsVisible = false;
  String? deadlineAt;
  int? lastResponseStatus;
  Completer<void>? voteGate;
  String? voteFailure;
  int voteStatus = 409;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.method == 'PUT') {
      if (voteGate != null) await voteGate!.future;
      if (voteFailure == 'NETWORK') {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      }
      if (voteFailure != null) {
        return ResponseBody.fromString(
          jsonEncode({'code': voteFailure}),
          voteStatus,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }
      votePayload = Map<String, dynamic>.from(options.data as Map);
      callerOptionIds = List<String>.from(votePayload!['optionIds'] as List);
    }
    lastResponseStatus = 200;
    return ResponseBody.fromString(
      jsonEncode(_pollJson()),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  Map<String, dynamic> _pollJson() => {
    'id': 'poll-1',
    'activityId': 'activity-1',
    'createdBy': 'user-1',
    'question': 'Where should we meet?',
    'pollType': 'SINGLE_CHOICE',
    'allowMemberAddOption': true,
    'voteVisibility': 'PUBLIC',
    'resultVisibility': resultsVisible ? 'IMMEDIATE' : 'AFTER_CLOSE',
    'status': closed ? 'CLOSED' : 'OPEN',
    'deadlineAt': deadlineAt,
    'resultsVisible': resultsVisible,
    'options': [
      {
        'id': 'option-1',
        'text': 'Park',
        'sortOrder': 0,
        'disabled': false,
        'voteCount': 0,
      },
      {
        'id': 'option-2',
        'text': 'Cafe',
        'sortOrder': 1,
        'disabled': false,
        'voteCount': 0,
      },
    ],
    'callerOptionIds': callerOptionIds,
    'permissions': {
      'canVote': canVote && !closed,
      'canAddOption': false,
      'canClose': false,
      'canViewVoters': false,
    },
  };

  @override
  void close({bool force = false}) {}
}
