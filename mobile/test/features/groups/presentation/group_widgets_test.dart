import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/l10n/app_strings.dart';
import 'package:mobile/core/models/paged_response.dart';
import 'package:mobile/features/groups/application/create_group_controller.dart';
import 'package:mobile/features/groups/application/group_detail_controller.dart';
import 'package:mobile/features/groups/application/groups_controller.dart';
import 'package:mobile/features/groups/data/group_api.dart';
import 'package:mobile/features/groups/data/group_failure.dart';
import 'package:mobile/features/groups/data/group_repository.dart';
import 'package:mobile/features/groups/data/models/group_models.dart';
import 'package:mobile/features/groups/presentation/screens/group_info_screen.dart';
import 'package:mobile/features/groups/presentation/screens/create_group_screen.dart';
import 'package:mobile/features/groups/presentation/screens/my_groups_screen.dart';
import 'package:mobile/features/groups/presentation/widgets/group_widgets.dart';

void main() {
  testWidgets('role badges map OWNER, ADMIN and MEMBER explicitly', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            GroupRoleBadge(role: GroupRole.owner),
            GroupRoleBadge(role: GroupRole.admin),
            GroupRoleBadge(role: GroupRole.member),
          ],
        ),
      ),
    );
    expect(find.text('OWNER'), findsOneWidget);
    expect(find.text('ADMIN'), findsOneWidget);
    expect(find.text('MEMBER'), findsOneWidget);
  });

  testWidgets('My Groups shows a server group and forwards its exact id', (
    tester,
  ) async {
    final controller = GroupsController(
      _repository(
        _Adapter({
          '/api/v1/groups': _page([_summary('exact-id')]),
        }),
      ),
    );
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: MyGroupsScreen(
          controller: controller,
          onCreate: () {},
          onOpenGroup: (id) => opened = id,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Group exact-id'), findsOneWidget);
    await tester.tap(find.text('Group exact-id'));
    expect(opened, 'exact-id');
  });

  testWidgets('My Groups empty CTA invokes the navigation callback', (
    tester,
  ) async {
    final controller = GroupsController(
      _repository(_Adapter({'/api/v1/groups': _page([])})),
    );
    var creates = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MyGroupsScreen(
          controller: controller,
          onCreate: () => creates++,
          onOpenGroup: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa có nhóm nào'), findsOneWidget);
    await tester.tap(find.text('Tạo nhóm').last);
    expect(creates, 1);
  });

  testWidgets('Groups loading recovers from a network failure when retried', (
    tester,
  ) async {
    final repository = _RecoveringGroupsRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: MyGroupsScreen(
          controller: GroupsController(repository),
          onCreate: () {},
          onOpenGroup: (_) {},
        ),
      ),
    );

    expect(find.text('Đang tải nhóm...'), findsOneWidget);
    await tester.pumpAndSettle();

    expect(
      find.text('Không thể kết nối mạng. Vui lòng kiểm tra lại.'),
      findsOneWidget,
    );
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.text('Thu lai'), findsNothing);

    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(repository.calls, 2);
    expect(find.text('Group recovered'), findsOneWidget);
    expect(find.text('Thử lại'), findsNothing);
  });

  testWidgets('Group Info renders fetched member count and bottom navigation', (
    tester,
  ) async {
    final controller = GroupDetailController(
      _repository(
        _Adapter({
          '/api/v1/groups/g': _detail(
            'OWNER',
            avatarStorageKey: 'avatars/canonical-group.png',
          ),
          '/api/v1/groups/g/members': [_member('a'), _member('b')],
        }),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GroupInfoScreen(
          groupId: 'g',
          controller: controller,
          onEdit: () {},
          onMembers: () {},
          onSettings: () {},
          onActivityLog: () {},
          onLeave: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Groups'), findsOneWidget);
    final avatar = tester.widget<GroupAvatar>(find.byType(GroupAvatar));
    expect(avatar.avatarStorageKey, 'avatars/canonical-group.png');
    expect(
      avatar.resolvedUrl,
      'http://localhost:8080/api/v1/media/avatars/canonical-group.png',
    );
    await tester.scrollUntilVisible(find.text('Rời nhóm'), 300);
    expect(find.text('Rời nhóm'), findsOneWidget);
  });

  testWidgets('Group Info shows Leave for non-owner callers', (tester) async {
    final controller = GroupDetailController(
      _repository(
        _Adapter({
          '/api/v1/groups/g': _detail('ADMIN'),
          '/api/v1/groups/g/members': [_member('a')],
        }),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GroupInfoScreen(
          groupId: 'g',
          controller: controller,
          onEdit: () {},
          onMembers: () {},
          onSettings: () {},
          onActivityLog: () {},
          onLeave: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Rời nhóm'), 300);
    expect(find.text('Rời nhóm'), findsOneWidget);
  });

  testWidgets('Create Group validates the required name before submission', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CreateGroupScreen(
          controller: CreateGroupController(_repository(_Adapter({}))),
          onCreated: (_) {},
        ),
      ),
    );
    await tester.tap(find.text(AppStrings.createGroup));
    await tester.pump();
    expect(find.text(AppStrings.groupNameRequired), findsOneWidget);
  });

  testWidgets('Create Group avatar action reports unavailable upload', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CreateGroupScreen(
          controller: CreateGroupController(_repository(_Adapter({}))),
          onCreated: (_) {},
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.add_a_photo));
    await tester.pump();
    expect(find.text(AppStrings.groupImageUnavailable), findsOneWidget);
  });

  testWidgets(
    'Create Group navigates only after authoritative detail succeeds',
    (tester) async {
      final controller = CreateGroupController(
        _repository(
          _Adapter({
            '/api/v1/groups': _created('new'),
            '/api/v1/groups/new': _detail('OWNER'),
          }),
        ),
      );
      GroupDetail? created;
      await tester.pumpWidget(
        MaterialApp(
          home: CreateGroupScreen(
            controller: controller,
            onCreated: (detail) => created = detail,
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField).first, 'New group');
      await tester.tap(find.text(AppStrings.createGroup));
      await tester.pumpAndSettle();
      expect(created?.id, 'g');
    },
  );
}

class _RecoveringGroupsRepository extends GroupRepository {
  _RecoveringGroupsRepository() : super(api: GroupApi(Dio()));

  int calls = 0;

  @override
  Future<PagedResponse<GroupSummary>> listGroups({
    int page = 0,
    int size = 30,
    GroupStatus status = GroupStatus.active,
  }) async {
    calls++;
    if (calls == 1) {
      throw const GroupException(GroupFailure(GroupFailureType.network));
    }
    return PagedResponse(
      items: [GroupSummary.fromJson(_summary('recovered'))],
      page: 0,
      size: 30,
      totalElements: 1,
      totalPages: 1,
      hasNext: false,
    );
  }
}

GroupRepository _repository(_Adapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://test'))
    ..httpClientAdapter = adapter;
  return GroupRepository(api: GroupApi(dio));
}

class _Adapter implements HttpClientAdapter {
  final Map<String, dynamic> data;
  _Adapter(this.data);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(data[options.path]),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _page(List<Map<String, dynamic>> items) => {
  'items': items,
  'page': 0,
  'size': 30,
  'totalElements': items.length,
  'totalPages': 1,
  'hasNext': false,
};
Map<String, dynamic> _summary(String id) => {
  'id': id,
  'name': 'Group $id',
  'avatarStorageKey': null,
  'status': 'ACTIVE',
  'callerRole': 'MEMBER',
  'updatedAt': '2026-01-01T00:00:00Z',
};
Map<String, dynamic> _detail(String role, {String? avatarStorageKey}) => {
  'id': 'g',
  'name': 'Group G',
  'description': null,
  'avatarStorageKey': avatarStorageKey,
  'status': 'ACTIVE',
  'ownerUserId': 'u',
  'callerRole': role,
  'createdAt': '2026-01-01T00:00:00Z',
  'updatedAt': '2026-01-01T00:00:00Z',
};
Map<String, dynamic> _created(String id) => {
  'id': id,
  'name': 'Group $id',
  'description': null,
  'avatarStorageKey': null,
  'status': 'ACTIVE',
  'createdBy': 'u',
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
