import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/activity/data/activity_api.dart';
import 'package:mobile/features/activity/data/activity_failure.dart';
import 'package:mobile/features/activity/data/activity_models.dart';
import 'package:mobile/features/activity/data/activity_repository.dart';

void main() {
  test('repository translates M7 server failure codes to ActivityFailure', () async {
    const cases = <String, ActivityFailureType>{
      'VALIDATION_FAILED': ActivityFailureType.validation,
      'ACTIVITY_NOT_FOUND': ActivityFailureType.notFound,
      'ACTIVITY_CLOSED': ActivityFailureType.closed,
      'ACTIVITY_ALREADY_STARTED': ActivityFailureType.alreadyStarted,
      'ACTIVITY_ALREADY_COMPLETED': ActivityFailureType.alreadyCompleted,
      'INVALID_ACTIVITY_TIME': ActivityFailureType.invalidTime,
      'ACTIVITY_CAPACITY_INVALID': ActivityFailureType.invalidCapacity,
      'RSVP_LOCKED': ActivityFailureType.rsvpLocked,
      'INSUFFICIENT_GROUP_PERMISSION': ActivityFailureType.permission,
      'SOME_RANDOM_CODE': ActivityFailureType.unknown,
    };

    for (final entry in cases.entries) {
      final repository = _repository(status: 400, code: entry.key);
      await expectLater(
        repository.detail('act-1'),
        throwsA(
          isA<ActivityException>().having(
            (error) => error.failure.type,
            'mapped failure',
            entry.value,
          ),
        ),
      );
    }

    final authRepo = _repository(status: 401, code: 'UNAUTHORIZED');
    await expectLater(
      authRepo.detail('act-1'),
      throwsA(
        isA<ActivityException>().having(
          (error) => error.failure.type,
          'mapped failure',
          ActivityFailureType.unauthorized,
        ),
      ),
    );
  });

  test('repository translates transport network failure', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://test'))
      ..httpClientAdapter = _NetworkFailureAdapter();
    final repository = ActivityRepository(api: ActivityApi(dio));

    await expectLater(
      repository.detail('act-1'),
      throwsA(
        isA<ActivityException>().having(
          (error) => error.failure.type,
          'mapped network failure',
          ActivityFailureType.network,
        ),
      ),
    );
  });

  test('repository delegates successfully for list and detail', () async {
    final adapter = _SuccessAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://test'))..httpClientAdapter = adapter;
    final repository = ActivityRepository(api: ActivityApi(dio));

    final detail = await repository.detail('act-1');
    expect(detail.id, 'act-1');
    expect(detail.title, 'Success Activity');

    final list = await repository.list('grp-1');
    expect(list.items.length, 1);
    expect(list.items.first.id, 'act-1');

    final rsvp = await repository.rsvp('act-1', ActivityRsvpStatus.going);
    expect(rsvp.status, ActivityRsvpStatus.going);

    final participants = await repository.participants('act-1');
    expect(participants.length, 1);
    expect(participants.first.userId, 'u1');
  });
}

ActivityRepository _repository({required int status, String code = 'ERROR'}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://test'))..httpClientAdapter = _ErrorAdapter(status: status, code: code);
  return ActivityRepository(api: ActivityApi(dio));
}

class _ErrorAdapter implements HttpClientAdapter {
  final int status;
  final String code;
  _ErrorAdapter({required this.status, required this.code});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = jsonEncode({
      'code': code,
      'message': 'Error message for $code',
    });
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _NetworkFailureAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      message: 'No internet connection',
    );
  }

  @override
  void close({bool force = false}) {}
}

class _SuccessAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    dynamic body;
    if (options.path.contains('/participants')) {
      body = [
        {
          'userId': 'u1',
          'username': 'user1',
          'displayName': 'User One',
          'status': 'GOING',
          'createdAt': '2030-01-01T00:00:00Z',
        }
      ];
    } else if (options.path.endsWith('/activities')) {
      body = {
        'items': [
          {
            'id': 'act-1',
            'groupId': 'grp-1',
            'title': 'Success Activity',
            'status': 'PLANNING',
            'startAt': '2030-01-01T10:00:00Z',
            'timezone': 'Asia/Ho_Chi_Minh',
            'callerRsvpStatus': 'GOING',
            'goingCount': 1,
            'waitlistCount': 0,
          }
        ],
        'page': 0,
        'size': 30,
        'totalElements': 1,
        'totalPages': 1,
        'hasNext': false,
      };
    } else if (options.path.endsWith('/rsvp')) {
      body = {
        'activityId': 'act-1',
        'userId': 'u1',
        'status': 'GOING',
        'effectiveLifecycleStatus': 'PLANNING',
      };
    } else {
      body = {
        'id': 'act-1',
        'groupId': 'grp-1',
        'title': 'Success Activity',
        'status': 'PLANNING',
        'startAt': '2030-01-01T10:00:00Z',
        'timezone': 'UTC',
        'createdAt': '2030-01-01T00:00:00Z',
        'updatedAt': '2030-01-01T00:00:00Z',
        'creator': {'userId': 'u1'},
        'callerRsvpStatus': 'GOING',
        'goingCount': 1,
        'maybeCount': 0,
        'notGoingCount': 0,
        'waitlistCount': 0,
        'permissions': {
          'canEdit': true,
          'canConfirm': true,
          'canCancel': true,
          'canComplete': false,
          'canRsvp': true,
        },
      };
    }

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
