import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/groups/application/create_group_controller.dart';
import 'package:mobile/features/groups/application/group_detail_controller.dart';
import 'package:mobile/features/groups/application/groups_controller.dart';
import 'package:mobile/features/groups/data/group_api.dart';
import 'package:mobile/features/groups/data/group_repository.dart';
import 'package:mobile/features/groups/data/models/group_models.dart';

void main() {
  test(
    'GroupsController requests ACTIVE page zero, preserves server order',
    () async {
      final adapter = _Adapter({
        '/api/v1/groups': _page(['b', 'a']),
      });
      final controller = GroupsController(_repository(adapter));
      await controller.load();
      expect(controller.value.phase, GroupsPhase.data);
      expect(controller.value.groups.map((e) => e.id), ['b', 'a']);
      expect(adapter.requests.single.queryParameters, {
        'page': 0,
        'size': 30,
        'status': 'ACTIVE',
      });
    },
  );

  test('GroupsController distinguishes empty and typed failure', () async {
    final empty = GroupsController(
      _repository(_Adapter({'/api/v1/groups': _page([])})),
    );
    await empty.load();
    expect(empty.value.phase, GroupsPhase.empty);
    final failed = GroupsController(
      _repository(_Adapter({}, status: 409, code: 'GROUP_ARCHIVED')),
    );
    await failed.load();
    expect(failed.value.phase, GroupsPhase.error);
  });

  test(
    'CreateGroupController loads authoritative detail by CreatedGroup id',
    () async {
      final adapter = _Adapter({
        '/api/v1/groups': _created('new'),
        '/api/v1/groups/new': _detail('new'),
      });
      final controller = CreateGroupController(_repository(adapter));
      final detail = await controller.submit(
        const CreateGroupRequest(name: 'N'),
      );
      expect(detail?.id, 'new');
      expect(adapter.requests.map((e) => e.path), [
        '/api/v1/groups',
        '/api/v1/groups/new',
      ]);
    },
  );

  test(
    'CreateGroupController returns no fake success when detail lookup fails',
    () async {
      final adapter = _Adapter({
        '/api/v1/groups': _created('new'),
      }, failPath: '/api/v1/groups/new');
      final detail = await CreateGroupController(_repository(adapter))
          .submit(const CreateGroupRequest(name: 'N'));
      expect(detail, isNull);
    },
  );

  test('GroupDetailController exposes real member count', () async {
    final adapter = _Adapter({
      '/api/v1/groups/g': _detail('g'),
      '/api/v1/groups/g/members': [_member('a'), _member('b')],
    });
    final controller = GroupDetailController(_repository(adapter));
    await controller.load('g');
    expect(controller.value.detail?.id, 'g');
    expect(controller.value.memberCount, 2);
  });

  test(
    'GroupDetailController preserves detail when member count fails',
    () async {
      final adapter = _Adapter({
        '/api/v1/groups/g': _detail('g'),
      }, failPath: '/api/v1/groups/g/members');
      final controller = GroupDetailController(_repository(adapter));
      await controller.load('g');
      expect(controller.value.detail?.id, 'g');
      expect(controller.value.memberCount, isNull);
      expect(controller.value.memberCountFailure, isNotNull);
    },
  );
}

GroupRepository _repository(_Adapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://test'))
    ..httpClientAdapter = adapter;
  return GroupRepository(api: GroupApi(dio));
}

class _Adapter implements HttpClientAdapter {
  final Map<String, dynamic> data;
  final List<RequestOptions> requests = [];
  final int status;
  final String? code, failPath;
  _Adapter(this.data, {this.status = 200, this.code, this.failPath});
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    requests.add(o);
    final failed = o.path == failPath || status >= 400;
    return ResponseBody.fromString(
      jsonEncode(
        failed ? {'code': code ?? 'GROUP_ARCHIVED'} : data[o.path] ?? {},
      ),
      failed ? 409 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _page(List<String> ids) => {
  'items': ids
      .map(
        (id) => {
          'id': id,
          'name': id,
          'avatarStorageKey': null,
          'status': 'ACTIVE',
          'callerRole': 'MEMBER',
          'updatedAt': '2026-01-01T00:00:00Z',
        },
      )
      .toList(),
  'page': 0,
  'size': 30,
  'totalElements': ids.length,
  'totalPages': 1,
  'hasNext': false,
};
Map<String, dynamic> _created(String id) => {
  'id': id,
  'name': 'N',
  'description': null,
  'avatarStorageKey': null,
  'status': 'ACTIVE',
  'createdBy': 'u',
  'createdAt': '2026-01-01T00:00:00Z',
  'updatedAt': '2026-01-01T00:00:00Z',
};
Map<String, dynamic> _detail(String id) => {
  'id': id,
  'name': 'N',
  'description': null,
  'avatarStorageKey': null,
  'status': 'ACTIVE',
  'ownerUserId': 'u',
  'callerRole': 'OWNER',
  'createdAt': '2026-01-01T00:00:00Z',
  'updatedAt': '2026-01-01T00:00:00Z',
};
Map<String, dynamic> _member(String id) => {
  'userId': id,
  'username': id,
  'displayName': id,
  'avatarStorageKey': null,
  'role': 'MEMBER',
  'joinedAt': '2026-01-01T00:00:00Z',
};
