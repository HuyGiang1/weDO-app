import 'package:dio/dio.dart';

import 'dart:math';

import '../../../core/network/api_exception.dart';
import 'poll_models.dart';

class PollApi {
  static String newCommandId() {
    final random = Random.secure();
    final b = List.generate(16, (_) => random.nextInt(256));
    b[6] = (b[6] & 15) | 64;
    b[8] = (b[8] & 63) | 128;
    final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  final Dio dio;
  PollApi(this.dio);
  Future<List<Poll>> listGroup(String groupId) => _list(
    () => dio.get('/api/v1/groups/${Uri.encodeComponent(groupId)}/polls'),
    Poll.fromJson,
  );
  Future<T> _object<T>(
    Future<Response<dynamic>> Function() call,
    T Function(Map<String, dynamic>) parse,
  ) async {
    try {
      final data = (await call()).data;
      if (data is! Map) throw const FormatException('Expected object');
      return parse(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<T>> _list<T>(
    Future<Response<dynamic>> Function() call,
    T Function(Map<String, dynamic>) parse,
  ) async {
    try {
      final data = (await call()).data;
      if (data is! List) throw const FormatException('Expected list');
      return data
          .map((e) => parse(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<Poll>> list(String activityId) => _list(
    () =>
        dio.get('/api/v1/activities/${Uri.encodeComponent(activityId)}/polls'),
    Poll.fromJson,
  );
  Future<Poll> get(String id) => _object(
    () => dio.get('/api/v1/polls/${Uri.encodeComponent(id)}'),
    Poll.fromJson,
  );
  Future<Poll> create(String activityId, CreatePollDraft d) => _object(
    () => dio.post(
      '/api/v1/activities/${Uri.encodeComponent(activityId)}/polls',
      data: d.toJson(),
    ),
    Poll.fromJson,
  );
  Future<Poll> vote(
    String id,
    List<String> optionIds, {
    String? clientRequestId,
  }) => _object(
    () => dio.put(
      '/api/v1/polls/${Uri.encodeComponent(id)}/vote',
      data: {
        'optionIds': optionIds,
        'clientRequestId': clientRequestId ?? newCommandId(),
      },
    ),
    Poll.fromJson,
  );
  Future<Poll> addOption(String id, String text) => _object(
    () => dio.post(
      '/api/v1/polls/${Uri.encodeComponent(id)}/options',
      data: {'text': text},
    ),
    Poll.fromJson,
  );
  Future<Poll> updateOption(
    String pollId,
    String optionId,
    String text,
  ) => _object(
    () => dio.patch(
      '/api/v1/polls/${Uri.encodeComponent(pollId)}/options/${Uri.encodeComponent(optionId)}',
      data: {'text': text},
    ),
    Poll.fromJson,
  );
  Future<void> deleteOption(String pollId, String optionId) async {
    try {
      await dio.delete(
        '/api/v1/polls/${Uri.encodeComponent(pollId)}/options/${Uri.encodeComponent(optionId)}',
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Poll> disableOption(String pollId, String optionId) => _object(
    () => dio.post(
      '/api/v1/polls/${Uri.encodeComponent(pollId)}/options/${Uri.encodeComponent(optionId)}/disable',
    ),
    Poll.fromJson,
  );
  Future<Poll> close(String id) => _object(
    () => dio.post('/api/v1/polls/${Uri.encodeComponent(id)}/close'),
    Poll.fromJson,
  );
  Future<List<PollVoters>> voters(String id) => _list(
    () => dio.get('/api/v1/polls/${Uri.encodeComponent(id)}/voters'),
    PollVoters.fromJson,
  );
}
