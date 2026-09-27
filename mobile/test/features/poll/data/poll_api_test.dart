import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/poll/data/poll_api.dart';
import 'package:mobile/features/poll/data/poll_models.dart';

void main() {
  late _PollAdapter adapter;
  late PollApi api;

  setUp(() {
    adapter = _PollAdapter();
    api = PollApi(
      Dio(BaseOptions(baseUrl: 'https://test'))..httpClientAdapter = adapter,
    );
  });

  test('create forwards the activity id and documented poll payload', () async {
    const activityId = '11111111-2222-3333-4444-555555555555';
    adapter.data['/api/v1/activities/$activityId/polls'] = _pollJson(
      activityId,
    );
    final deadline = DateTime(2030, 5, 1, 9, 30);

    final result = await api.create(
      activityId,
      CreatePollDraft(
        question: 'Where should we meet?',
        options: const ['Park', 'Cafe'],
        allowMemberAddOption: true,
        anonymous: true,
        showResultsImmediately: false,
        deadlineAt: deadline,
      ),
    );
    final request = adapter.requests.single;

    expect(request.method, 'POST');
    expect(request.path, '/api/v1/activities/$activityId/polls');
    expect(request.data, {
      'question': 'Where should we meet?',
      'pollType': 'SINGLE_CHOICE',
      'options': ['Park', 'Cafe'],
      'allowMemberAddOption': true,
      'voteVisibility': 'ANONYMOUS',
      'resultVisibility': 'AFTER_CLOSE',
      'deadlineAt': deadline.toUtc().toIso8601String(),
    });
    expect(result.activityId, activityId);
  });

  test('create maps a validation response to ApiException', () async {
    const activityId = '11111111-2222-3333-4444-555555555555';
    adapter.statusCodes['/api/v1/activities/$activityId/polls'] = 400;
    adapter.data['/api/v1/activities/$activityId/polls'] = {
      'status': 400,
      'code': 'VALIDATION_FAILED',
      'message': 'Request validation failed.',
      'errors': {'request': 'Malformed request body.'},
    };

    await expectLater(
      api.create(
        activityId,
        const CreatePollDraft(
          question: 'Question',
          options: ['A', 'B'],
          allowMemberAddOption: false,
          anonymous: false,
          showResultsImmediately: true,
        ),
      ),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 400)
            .having((error) => error.code, 'code', 'VALIDATION_FAILED')
            .having(
              (error) => error.fieldErrors['request'],
              'request error',
              'Malformed request body.',
            ),
      ),
    );
  });
}

Map<String, dynamic> _pollJson(String activityId) => {
  'id': 'poll-1',
  'activityId': activityId,
  'createdBy': 'user-1',
  'question': 'Where should we meet?',
  'pollType': 'MULTIPLE_CHOICE',
  'allowMemberAddOption': true,
  'maxSelections': 2,
  'voteVisibility': 'ANONYMOUS',
  'resultVisibility': 'AFTER_CLOSE',
  'status': 'OPEN',
  'resultsVisible': false,
  'options': const [],
  'callerOptionIds': const [],
  'permissions': const {
    'canVote': true,
    'canAddOption': true,
    'canClose': true,
    'canViewVoters': false,
  },
};

class _PollAdapter implements HttpClientAdapter {
  final data = <String, dynamic>{};
  final statusCodes = <String, int>{};
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(data[options.path] ?? {}),
      statusCodes[options.path] ?? 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
