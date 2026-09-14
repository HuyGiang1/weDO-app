import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/paged_response.dart';
import 'package:mobile/features/groups/application/group_detail_controller.dart';
import 'package:mobile/features/groups/application/group_management_controllers.dart';
import 'package:mobile/features/groups/application/groups_controller.dart';
import 'package:mobile/features/groups/data/group_api.dart';
import 'package:mobile/features/groups/data/group_failure.dart';
import 'package:mobile/features/groups/data/group_repository.dart';
import 'package:mobile/features/groups/data/models/group_models.dart';
import 'package:mobile/features/groups/presentation/screens/group_info_screen.dart';
import 'package:mobile/features/groups/presentation/screens/group_management_screens.dart';
import 'package:mobile/features/groups/presentation/screens/my_groups_screen.dart';

void main() {
  testWidgets('kick closes Member Management and refreshes Group Members', (
    tester,
  ) async {
    final repo = _E2eRepo();
    await tester.pumpWidget(MaterialApp(home: _KickFlow(repo)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('member'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove member'));
    await tester.pumpAndSettle();

    expect(repo.kickGroupId, 'group-id');
    expect(repo.kickUserId, 'member');
    expect(find.text('Member Management'), findsNothing);
    expect(repo.memberLoadCount, 2);
    expect(find.text('member'), findsNothing);
  });

  testWidgets('transfer applies authoritative ADMIN detail and removes OWNER controls', (
    tester,
  ) async {
    final repo = _E2eRepo();
    await tester.pumpWidget(MaterialApp(home: _TransferFlow(repo)));
    await tester.pumpAndSettle();
    expect(_switch(tester, 0).onChanged, isNotNull);

    await tester.tap(find.text('Transfer ownership'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('member'));
    await tester.pumpAndSettle();

    expect(repo.transferGroupId, 'group-id');
    expect(repo.transferUserId, 'member');
    expect(repo.detail.ownerUserId, 'member');
    expect(repo.detail.callerRole, GroupRole.admin);
    expect(find.text('Transfer Ownership'), findsNothing);
    expect(_switch(tester, 0).onChanged, isNull);
    expect(
      tester.widget<ListTile>(find.widgetWithText(ListTile, 'Transfer ownership')).onTap,
      isNull,
    );
  });

  testWidgets('ADMIN leave closes Group Info and refreshes My Groups', (
    tester,
  ) async {
    final repo = _E2eRepo(role: GroupRole.admin);
    await tester.pumpWidget(MaterialApp(home: _LeaveFlow(repo)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Group G'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Leave Group'), 300);
    await tester.tap(find.text('Leave Group'));
    await tester.pumpAndSettle();

    expect(repo.leaveGroupId, 'group-id');
    expect(find.text('Group Info'), findsNothing);
    expect(repo.listLoadCount, greaterThanOrEqualTo(2));
    expect(find.text('Group G'), findsNothing);
  });

  testWidgets('OWNER leave transfer-required keeps Group Info open with safe message', (
    tester,
  ) async {
    final repo = _E2eRepo(transferRequired: true);
    var left = false;
    await tester.pumpWidget(
      MaterialApp(
        home: GroupInfoScreen(
          groupId: 'group-id',
          controller: GroupDetailController(repo),
          onEdit: () {},
          onMembers: () {},
          onSettings: () {},
          onActivityLog: () {},
          onLeave: () => left = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Leave Group'), 300);
    await tester.tap(find.text('Leave Group'));
    await tester.pumpAndSettle();

    expect(repo.leaveGroupId, 'group-id');
    expect(left, isFalse);
    expect(find.text('Group Info'), findsOneWidget);
    expect(
      find.text('Transfer ownership before leaving this group.'),
      findsOneWidget,
    );
    expect(find.byType(GroupInfoScreen), findsOneWidget);
  });
}

SwitchListTile _switch(WidgetTester tester, int index) =>
    tester.widget<SwitchListTile>(find.byType(SwitchListTile).at(index));

class _KickFlow extends StatefulWidget {
  final _E2eRepo repo;
  const _KickFlow(this.repo);
  @override
  State<_KickFlow> createState() => _KickFlowState();
}

class _KickFlowState extends State<_KickFlow> {
  late final GroupMembersController members = GroupMembersController(widget.repo);
  @override
  Widget build(BuildContext context) => GroupMembersScreen(
    groupId: 'group-id',
    controller: members,
    onMember: (userId) async {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (childContext) => MemberManagementScreen(
            groupId: 'group-id',
            userId: userId,
            controller: MemberManagementController(widget.repo),
            onKicked: () => Navigator.of(childContext).pop(true),
          ),
        ),
      );
      if (result == true) await members.load('group-id');
    },
  );
}

class _TransferFlow extends StatefulWidget {
  final _E2eRepo repo;
  const _TransferFlow(this.repo);
  @override
  State<_TransferFlow> createState() => _TransferFlowState();
}

class _TransferFlowState extends State<_TransferFlow> {
  late final GroupPermissionsController permissions =
      GroupPermissionsController(widget.repo);
  @override
  Widget build(BuildContext context) => GroupPermissionsScreen(
    groupId: 'group-id',
    controller: permissions,
    onTransfer: () async {
      final result = await Navigator.of(context).push<GroupDetail>(
        MaterialPageRoute(
          builder: (childContext) => TransferOwnershipScreen(
            groupId: 'group-id',
            controller: TransferOwnershipController(widget.repo),
            onTransferred: (detail) => Navigator.of(childContext).pop(detail),
          ),
        ),
      );
      if (result != null) await permissions.load('group-id');
    },
  );
}

class _LeaveFlow extends StatefulWidget {
  final _E2eRepo repo;
  const _LeaveFlow(this.repo);
  @override
  State<_LeaveFlow> createState() => _LeaveFlowState();
}

class _LeaveFlowState extends State<_LeaveFlow> {
  late final GroupsController groups = GroupsController(widget.repo);
  @override
  Widget build(BuildContext context) => MyGroupsScreen(
    controller: groups,
    onCreate: () {},
    onOpenGroup: (_) async {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (childContext) => GroupInfoScreen(
            groupId: 'group-id',
            controller: GroupDetailController(widget.repo),
            onEdit: () {},
            onMembers: () {},
            onSettings: () {},
            onActivityLog: () {},
            onLeave: () => Navigator.of(childContext).pop(true),
          ),
        ),
      );
      if (result == true) await groups.refresh();
    },
  );
}

class _E2eRepo extends GroupRepository {
  _E2eRepo({GroupRole role = GroupRole.owner, this.transferRequired = false})
    : detail = _detail(role),
      super(api: GroupApi(Dio()));

  GroupDetail detail;
  final bool transferRequired;
  final List<GroupMember> _members = [
    _member('owner', GroupRole.owner),
    _member('member', GroupRole.member),
    _member('admin', GroupRole.admin),
  ];
  int memberLoadCount = 0;
  int listLoadCount = 0;
  String? kickGroupId, kickUserId, leaveGroupId, transferGroupId, transferUserId;
  bool belongsToGroup = true;

  @override
  Future<GroupDetail> getGroup(String id) async => detail;
  @override
  Future<List<GroupMember>> getMembers(String id) async {
    memberLoadCount++;
    return List.of(_members);
  }

  @override
  Future<GroupMember> getMember(String id, String userId) async =>
      _members.firstWhere((member) => member.userId == userId);
  @override
  Future<GroupSettings> getSettings(String id) async => GroupSettings(
    groupId: id,
    joinPolicy: GroupJoinPolicy.autoJoin,
    memberModifyInfoAllowed: true,
    memberCreateActivityAllowed: true,
    memberPinMessageAllowed: false,
    chatHistoryPolicy: ChatHistoryPolicy.fullHistory,
    updatedAt: DateTime(2026),
  );

  @override
  Future<void> kickMember(String id, String userId) async {
    kickGroupId = id;
    kickUserId = userId;
    _members.removeWhere((member) => member.userId == userId);
  }

  @override
  Future<void> leaveGroup(String id) async {
    leaveGroupId = id;
    if (transferRequired) {
      throw const GroupException(GroupFailure(GroupFailureType.transferRequired));
    }
    belongsToGroup = false;
  }

  @override
  Future<GroupDetail> transferOwnership(
    String id,
    TransferOwnershipRequest request,
  ) async {
    transferGroupId = id;
    transferUserId = request.newOwnerUserId;
    detail = _detail(GroupRole.admin, ownerUserId: request.newOwnerUserId);
    return detail;
  }

  @override
  Future<PagedResponse<GroupSummary>> listGroups({
    int page = 0,
    int size = 30,
    GroupStatus status = GroupStatus.active,
  }) async {
    listLoadCount++;
    final items = belongsToGroup
        ? [
            GroupSummary(
              id: 'group-id',
              name: 'Group G',
              status: GroupStatus.active,
              callerRole: detail.callerRole,
              updatedAt: DateTime(2026),
            ),
          ]
        : <GroupSummary>[];
    return PagedResponse(
      items: items,
      page: page,
      size: size,
      totalElements: items.length,
      totalPages: 1,
      hasNext: false,
    );
  }
}

GroupDetail _detail(GroupRole role, {String ownerUserId = 'owner'}) => GroupDetail(
  id: 'group-id',
  name: 'Group G',
  status: GroupStatus.active,
  ownerUserId: ownerUserId,
  callerRole: role,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

GroupMember _member(String id, GroupRole role) => GroupMember(
  userId: id,
  username: id,
  displayName: id,
  role: role,
  joinedAt: DateTime(2026),
);
