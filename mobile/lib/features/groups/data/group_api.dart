import 'package:dio/dio.dart';

import '../../../core/models/paged_response.dart';
import '../../../core/network/api_exception.dart';
import 'models/group_models.dart';

class GroupApi {
  final Dio dio;
  GroupApi(this.dio);
  Future<T> _call<T>(
    Future<Response<dynamic>> Function() r,
    T Function(Map<String, dynamic>) p,
  ) async {
    try {
      final d = (await r()).data;
      if (d is! Map) throw const FormatException('Expected JSON object');
      return p(Map<String, dynamic>.from(d));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<T>> _list<T>(
    Future<Response<dynamic>> Function() r,
    T Function(Map<String, dynamic>) p,
  ) async {
    try {
      final d = (await r()).data;
      if (d is! List) throw const FormatException('Expected JSON list');
      return d.map((item) {
        if (item is! Map) {
          throw const FormatException('Expected JSON object in list');
        }
        return p(Map<String, dynamic>.from(item));
      }).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> _empty(Future<Response<dynamic>> Function() r) async {
    try {
      await r();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<PagedResponse<GroupSummary>> listGroups({
    int page = 0,
    int size = 30,
    required GroupStatus status,
  }) => _call(
    () => dio.get(
      '/api/v1/groups',
      queryParameters: {'page': page, 'size': size, 'status': status.wireValue},
    ),
    (j) => PagedResponse.fromJson(j, GroupSummary.fromJson),
  );
  Future<PagedResponse<GroupActivityLog>> getActivityLogs(
    String id, {
    int page = 0,
    int size = 30,
  }) => _call(
    () => dio.get(
      '/api/v1/groups/${Uri.encodeComponent(id)}/activity-logs',
      queryParameters: {'page': page, 'size': size},
    ),
    (j) => PagedResponse.fromJson(j, GroupActivityLog.fromJson),
  );
  Future<CreatedGroup> create(CreateGroupRequest q) => _call(
    () => dio.post('/api/v1/groups', data: q.toJson()),
    CreatedGroup.fromJson,
  );
  Future<GroupDetail> getGroup(String id) => _call(
    () => dio.get('/api/v1/groups/${Uri.encodeComponent(id)}'),
    GroupDetail.fromJson,
  );
  Future<List<GroupMember>> getMembers(String id) => _list(
    () => dio.get('/api/v1/groups/${Uri.encodeComponent(id)}/members'),
    GroupMember.fromJson,
  );
  Future<GroupMember> getMember(String id, String u) => _call(
    () => dio.get(
      '/api/v1/groups/${Uri.encodeComponent(id)}/members/${Uri.encodeComponent(u)}',
    ),
    GroupMember.fromJson,
  );
  Future<GroupDetail> updateGroup(String id, UpdateGroupRequest q) => _call(
    () => dio.patch(
      '/api/v1/groups/${Uri.encodeComponent(id)}',
      data: q.toJson(),
    ),
    GroupDetail.fromJson,
  );
  Future<GroupSettings> getSettings(String id) => _call(
    () => dio.get('/api/v1/groups/${Uri.encodeComponent(id)}/settings'),
    GroupSettings.fromJson,
  );
  Future<GroupSettings> updateSettings(
    String id,
    UpdateGroupSettingsRequest q,
  ) => _call(
    () => dio.patch(
      '/api/v1/groups/${Uri.encodeComponent(id)}/settings',
      data: q.toJson(),
    ),
    GroupSettings.fromJson,
  );
  Future<GroupMember> promote(String id, String u) => _call(
    () => dio.post(
      '/api/v1/groups/${Uri.encodeComponent(id)}/members/${Uri.encodeComponent(u)}/promote-admin',
    ),
    GroupMember.fromJson,
  );
  Future<GroupMember> demote(String id, String u) => _call(
    () => dio.post(
      '/api/v1/groups/${Uri.encodeComponent(id)}/members/${Uri.encodeComponent(u)}/demote-admin',
    ),
    GroupMember.fromJson,
  );
  Future<void> kick(String id, String u) => _empty(
    () => dio.post(
      '/api/v1/groups/${Uri.encodeComponent(id)}/members/${Uri.encodeComponent(u)}/kick',
    ),
  );
  Future<void> leave(String id) =>
      _empty(() => dio.post('/api/v1/groups/${Uri.encodeComponent(id)}/leave'));
  Future<GroupDetail> transfer(String id, TransferOwnershipRequest q) => _call(
    () => dio.post(
      '/api/v1/groups/${Uri.encodeComponent(id)}/transfer-ownership',
      data: q.toJson(),
    ),
    GroupDetail.fromJson,
  );
}
