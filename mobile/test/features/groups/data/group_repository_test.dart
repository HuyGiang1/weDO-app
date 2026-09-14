import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/groups/data/group_api.dart';
import 'package:mobile/features/groups/data/group_failure.dart';
import 'package:mobile/features/groups/data/group_repository.dart';

void main() {
  test(
    'repository translates M5 server failures and does not expose DioException',
    () async {
      const cases = <String, GroupFailureType>{
        'VALIDATION_FAILED': GroupFailureType.validation,
        'GROUP_NOT_FOUND': GroupFailureType.groupNotFound,
        'GROUP_MEMBER_NOT_FOUND': GroupFailureType.memberNotFound,
        'GROUP_ARCHIVED': GroupFailureType.archived,
        'INSUFFICIENT_GROUP_PERMISSION':
            GroupFailureType.insufficientPermission,
        'TRANSFER_OWNERSHIP_REQUIRED': GroupFailureType.transferRequired,
        'INVALID_OWNERSHIP_TARGET': GroupFailureType.invalidOwnershipTarget,
        'INVALID_GROUP_ROLE_TRANSITION': GroupFailureType.invalidRoleTransition,
        'UNRECOGNIZED_GROUP_ERROR': GroupFailureType.unknown,
      };

      for (final entry in cases.entries) {
        final repository = _repository(status: 409, code: entry.key);
        await expectLater(
          repository.getGroup('g'),
          throwsA(
            isA<GroupException>().having(
              (error) => error.failure.type,
              'mapped failure',
              entry.value,
            ),
          ),
        );
      }

      await expectLater(
        _repository(status: 401).getGroup('g'),
        throwsA(
          isA<GroupException>().having(
            (error) => error.failure.type,
            'mapped failure',
            GroupFailureType.unauthorized,
          ),
        ),
      );
    },
  );

  test('repository translates a transport failure', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://test'))
      ..httpClientAdapter = _FailureAdapter();
    final repository = GroupRepository(api: GroupApi(dio));

    await expectLater(
      repository.getGroup('g'),
      throwsA(
        isA<GroupException>().having(
          (error) => error.failure.type,
          'mapped failure',
          GroupFailureType.network,
        ),
      ),
    );
  });
}

GroupRepository _repository({required int status, String? code}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://test'))
    ..httpClientAdapter = _ErrorAdapter(status: status, code: code);
  return GroupRepository(api: GroupApi(dio));
}

class _ErrorAdapter implements HttpClientAdapter {
  final int status;
  final String? code;

  _ErrorAdapter({required this.status, this.code});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({'code': code, 'message': 'failure'}),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

class _FailureAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => Future<ResponseBody>.error(
    DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
    ),
  );

  @override
  void close({bool force = false}) {}
}
