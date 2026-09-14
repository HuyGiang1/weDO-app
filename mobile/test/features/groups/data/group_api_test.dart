import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/groups/data/group_api.dart';
import 'package:mobile/features/groups/data/models/group_models.dart';

void main() {
  late _Adapter adapter;
  late GroupApi api;

  setUp(() {
    adapter = _Adapter();
    api = GroupApi(
      Dio(BaseOptions(baseUrl: 'https://test'))..httpClientAdapter = adapter,
    );
  });

  test('listGroups sends exact query and decodes shared pagination', () async {
    adapter.data['/api/v1/groups'] = _pageFixture();

    final page = await api.listGroups(
      page: 2,
      size: 30,
      status: GroupStatus.archived,
    );
    final request = adapter.requests.single;

    expect(request.method, 'GET');
    expect(request.path, '/api/v1/groups');
    expect(request.queryParameters, {
      'page': 2,
      'size': 30,
      'status': 'ARCHIVED',
    });
    expect(page.items.map((item) => item.id), ['first', 'second']);
    expect(page.page, 2);
    expect(page.totalElements, 91);
  });

  test('activity logs send exact query and preserve backend order with nullable ids', () async {
    adapter.data['/api/v1/groups/g/activity-logs'] = {
      'items': [
        {
          'id': 'newest',
          'action': 'GROUP_UPDATED',
          'actorUserId': null,
          'targetUserId': 'target',
          'createdAt': '2026-01-02T00:00:00Z',
        },
        {
          'id': 'older',
          'action': 'GROUP_CREATED',
          'actorUserId': 'actor',
          'targetUserId': null,
          'createdAt': '2026-01-01T00:00:00Z',
        },
      ],
      'page': 0,
      'size': 30,
      'totalElements': 2,
      'totalPages': 1,
      'hasNext': false,
    };

    final page = await api.getActivityLogs('g');
    expect(adapter.requests.single.path, '/api/v1/groups/g/activity-logs');
    expect(adapter.requests.single.queryParameters, {'page': 0, 'size': 30});
    expect(page.items.map((item) => item.id), ['newest', 'older']);
    expect(page.items.first.actorUserId, isNull);
    expect(page.items.last.targetUserId, isNull);
  });

  test(
    'create sends only supplied fields and decodes create response',
    () async {
      adapter.data['/api/v1/groups'] = _createdGroupFixture();

      final created = await api.create(
        const CreateGroupRequest(
          name: 'N',
          description: 'Description',
          avatarStorageKey: 'avatars/n',
        ),
      );
      final request = adapter.requests.single;

      expect(request.method, 'POST');
      expect(request.path, '/api/v1/groups');
      expect(request.data, {
        'name': 'N',
        'description': 'Description',
        'avatarStorageKey': 'avatars/n',
      });
      expect(created.createdBy, 'u');
    },
  );

  test('create omits unspecified nullable fields', () async {
    adapter.data['/api/v1/groups'] = _createdGroupFixture();

    await api.create(const CreateGroupRequest(name: 'N'));

    expect(adapter.requests.single.data, {'name': 'N'});
  });

  test('members decodes ordered JSON array and sends exact path', () async {
    adapter.data['/api/v1/groups/g/members'] = [
      _memberFixture('a'),
      _memberFixture('b', role: 'MEMBER'),
    ];

    final members = await api.getMembers('g');
    final request = adapter.requests.single;

    expect(request.method, 'GET');
    expect(request.path, '/api/v1/groups/g/members');
    expect(members.map((member) => member.userId), ['a', 'b']);
    expect(members[1].role, GroupRole.member);
  });

  test('individual member decodes object and sends exact path', () async {
    adapter.data['/api/v1/groups/g/members/u'] = _memberFixture(
      'u',
      role: 'ADMIN',
    );

    final member = await api.getMember('g', 'u');
    final request = adapter.requests.single;

    expect(request.method, 'GET');
    expect(request.path, '/api/v1/groups/g/members/u');
    expect(member.role, GroupRole.admin);
  });

  test(
    'updateGroup sends only present values and preserves clearing commands',
    () async {
      adapter.data['/api/v1/groups/g'] = _detailFixture();

      await api.updateGroup(
        'g',
        const UpdateGroupRequest(description: '', avatarStorageKey: ''),
      );
      final request = adapter.requests.single;

      expect(request.method, 'PATCH');
      expect(request.path, '/api/v1/groups/g');
      expect(request.data, {'description': '', 'avatarStorageKey': ''});
    },
  );

  test('settings PATCH preserves false and has no fabricated fields', () async {
    adapter.data['/api/v1/groups/g/settings'] = _settingsFixture();

    await api.updateSettings(
      'g',
      const UpdateGroupSettingsRequest(memberModifyInfoAllowed: false),
    );
    final request = adapter.requests.single;

    expect(request.method, 'PATCH');
    expect(request.path, '/api/v1/groups/g/settings');
    expect(request.data, {'memberModifyInfoAllowed': false});
  });

  test('promote and demote send exact POST paths and decode members', () async {
    adapter.data['/api/v1/groups/g/members/u/promote-admin'] = _memberFixture(
      'u',
      role: 'ADMIN',
    );
    adapter.data['/api/v1/groups/g/members/u/demote-admin'] = _memberFixture(
      'u',
      role: 'MEMBER',
    );

    final promoted = await api.promote('g', 'u');
    final demoted = await api.demote('g', 'u');

    expect(adapter.requests[0].method, 'POST');
    expect(
      adapter.requests[0].path,
      '/api/v1/groups/g/members/u/promote-admin',
    );
    expect(adapter.requests[0].data, isNull);
    expect(promoted.role, GroupRole.admin);
    expect(adapter.requests[1].method, 'POST');
    expect(adapter.requests[1].path, '/api/v1/groups/g/members/u/demote-admin');
    expect(adapter.requests[1].data, isNull);
    expect(demoted.role, GroupRole.member);
  });

  test('kick and leave send exact POST paths and accept 204', () async {
    await api.kick('g', 'u');
    await api.leave('g');

    expect(adapter.requests[0].method, 'POST');
    expect(adapter.requests[0].path, '/api/v1/groups/g/members/u/kick');
    expect(adapter.requests[1].method, 'POST');
    expect(adapter.requests[1].path, '/api/v1/groups/g/leave');
  });

  test('transfer sends exact POST path and exact body', () async {
    adapter.data['/api/v1/groups/g/transfer-ownership'] = _detailFixture();

    await api.transfer('g', const TransferOwnershipRequest('new-owner'));
    final request = adapter.requests.single;

    expect(request.method, 'POST');
    expect(request.path, '/api/v1/groups/g/transfer-ownership');
    expect(request.data, {'newOwnerUserId': 'new-owner'});
  });
}

Map<String, dynamic> _createdGroupFixture() => {
  'id': 'g',
  'name': 'N',
  'description': null,
  'avatarStorageKey': null,
  'status': 'ACTIVE',
  'createdBy': 'u',
  'createdAt': '2026-01-01T00:00:00Z',
  'updatedAt': '2026-01-01T00:00:00Z',
};

Map<String, dynamic> _detailFixture() => {
  'id': 'g',
  'name': 'N',
  'description': null,
  'avatarStorageKey': null,
  'status': 'ACTIVE',
  'ownerUserId': 'owner',
  'callerRole': 'OWNER',
  'createdAt': '2026-01-01T00:00:00Z',
  'updatedAt': '2026-01-01T00:00:00Z',
};

Map<String, dynamic> _memberFixture(String id, {String role = 'OWNER'}) => {
  'userId': id,
  'username': id,
  'displayName': id.toUpperCase(),
  'avatarStorageKey': null,
  'role': role,
  'joinedAt': '2026-01-01T00:00:00Z',
};

Map<String, dynamic> _settingsFixture() => {
  'groupId': 'g',
  'joinPolicy': 'AUTO_JOIN',
  'memberModifyInfoAllowed': false,
  'memberCreateActivityAllowed': false,
  'memberPinMessageAllowed': false,
  'chatHistoryPolicy': 'FULL_HISTORY',
  'updatedAt': '2026-01-01T00:00:00Z',
};

Map<String, dynamic> _pageFixture() => {
  'items': [
    {
      'id': 'first',
      'name': 'First',
      'avatarStorageKey': null,
      'status': 'ACTIVE',
      'callerRole': 'MEMBER',
      'updatedAt': '2026-01-01T00:00:00Z',
    },
    {
      'id': 'second',
      'name': 'Second',
      'avatarStorageKey': 'avatars/second',
      'status': 'ARCHIVED',
      'callerRole': 'ADMIN',
      'updatedAt': '2026-01-02T00:00:00Z',
    },
  ],
  'page': 2,
  'size': 30,
  'totalElements': 91,
  'totalPages': 4,
  'hasNext': true,
};

class _Adapter implements HttpClientAdapter {
  final data = <String, dynamic>{};
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final noContent =
        options.path.endsWith('/kick') || options.path.endsWith('/leave');
    return ResponseBody.fromString(
      noContent ? '' : jsonEncode(data[options.path] ?? {}),
      noContent ? 204 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
