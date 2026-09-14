import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/groups/application/group_management_controllers.dart';
import 'package:mobile/features/groups/data/group_api.dart';
import 'package:mobile/features/groups/data/group_repository.dart';
import 'package:mobile/features/groups/data/models/group_models.dart';
import 'package:mobile/features/groups/presentation/screens/group_management_screens.dart';

void main() {
  testWidgets('member row forwards its exact user id', (tester) async {
    String? id;
    final repo = _Repo();
    await tester.pumpWidget(
      MaterialApp(
        home: GroupMembersScreen(
          groupId: 'g',
          controller: GroupMembersController(repo),
          onMember: (v) => id = v,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('member'));
    expect(id, 'member');
    expect(repo.memberListGroup, 'g');
  });
  testWidgets('transfer presents both member and admin, never owner', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TransferOwnershipScreen(
          groupId: 'g',
          controller: TransferOwnershipController(_Repo()),
          onTransferred: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('member'), findsOneWidget);
    expect(find.text('admin'), findsOneWidget);
    expect(find.text('owner'), findsNothing);
  });
  testWidgets('member management exposes no unsupported Ban or Message', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MemberManagementScreen(
          groupId: 'g',
          userId: 'member',
          controller: MemberManagementController(_Repo()),
          onKicked: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ban User'), findsNothing);
    expect(find.text('Message'), findsNothing);
    expect(find.text('Add Friend'), findsNothing);
  });
}

class _Repo extends GroupRepository {
  String? memberListGroup;
  _Repo() : super(api: GroupApi(Dio()));
  @override
  Future<GroupDetail> getGroup(String id) async => GroupDetail(
    id: 'g',
    name: 'G',
    status: GroupStatus.active,
    ownerUserId: 'owner',
    callerRole: GroupRole.owner,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  @override
  Future<List<GroupMember>> getMembers(String id) async {
    memberListGroup = id;
    return [
      _m('owner', GroupRole.owner),
      _m('member', GroupRole.member),
      _m('admin', GroupRole.admin),
    ];
  }

  @override
  Future<GroupMember> getMember(String id, String u) async =>
      _m(u, GroupRole.member);
}

GroupMember _m(String id, GroupRole role) => GroupMember(
  userId: id,
  username: id,
  displayName: id,
  role: role,
  joinedAt: DateTime(2026),
);
