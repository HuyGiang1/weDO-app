import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/groups/application/group_management_controllers.dart';
import 'package:mobile/features/groups/data/group_api.dart';
import 'package:mobile/features/groups/data/group_failure.dart';
import 'package:mobile/features/groups/data/group_repository.dart';
import 'package:mobile/features/groups/data/models/group_models.dart';

// ignore_for_file: curly_braces_in_flow_control_structures

void main() {
  test('owner promote and demote use exact group and member ids', () async {
    final repo = _Repo();
    final c = GroupAdminController(repo);
    await c.load('g');
    await c.promote('g', 'member');
    expect(repo.promoted, ['g', 'member']);
    expect(c.value.data!.members[1].role, GroupRole.admin);
    await c.demote('g', 'admin');
    expect(repo.demoted, ['g', 'admin']);
    expect(c.value.data!.members[2].role, GroupRole.member);
  });
  test('kick reports success to caller with exact target', () async {
    final repo = _Repo();
    final c = MemberManagementController(repo);
    await c.load('g', 'member');
    expect(await c.kick('g', 'member'), isTrue);
    expect(repo.kicked, ['g', 'member']);
  });
  test('transfer uses authoritative returned detail', () async {
    final repo = _Repo();
    final c = TransferOwnershipController(repo);
    await c.load('g');
    final r = await c.transfer('g', 'member');
    expect(repo.transferred, ['g', 'member']);
    expect(r!.ownerUserId, 'member');
    expect(r.callerRole, GroupRole.admin);
    expect(c.value.data!.group.callerRole, GroupRole.admin);
  });
  test('invalid transfer retains typed failure and no success', () async {
    final repo = _Repo(failTransfer: true);
    final c = TransferOwnershipController(repo);
    await c.load('g');
    expect(await c.transfer('g', 'member'), isNull);
    expect(c.value.failure!.type, GroupFailureType.invalidOwnershipTarget);
  });
  test('permissions explicit false reaches repository', () async {
    final repo = _Repo();
    final c = GroupPermissionsController(repo);
    await c.load('g');
    await c.save(
      'g',
      const UpdateGroupSettingsRequest(memberModifyInfoAllowed: false),
    );
    expect(repo.settingsRequest!.toJson(), {'memberModifyInfoAllowed': false});
  });
}

class _Repo extends GroupRepository {
  List<String>? promoted, demoted, kicked, transferred;
  final bool failTransfer;
  UpdateGroupSettingsRequest? settingsRequest;
  _Repo({this.failTransfer = false}) : super(api: GroupApi(Dio()));
  @override
  Future<GroupDetail> getGroup(String id) async => _detail();
  @override
  Future<List<GroupMember>> getMembers(String id) async => [
    _member('owner', GroupRole.owner),
    _member('member', GroupRole.member),
    _member('admin', GroupRole.admin),
  ];
  @override
  Future<GroupMember> getMember(String id, String user) async =>
      _member(user, GroupRole.member);
  @override
  Future<GroupMember> promoteAdmin(String id, String user) async {
    promoted = [id, user];
    return _member(user, GroupRole.admin);
  }

  @override
  Future<GroupMember> demoteAdmin(String id, String user) async {
    demoted = [id, user];
    return _member(user, GroupRole.member);
  }

  @override
  Future<void> kickMember(String id, String user) async {
    kicked = [id, user];
  }

  @override
  Future<GroupDetail> transferOwnership(
    String id,
    TransferOwnershipRequest q,
  ) async {
    transferred = [id, q.newOwnerUserId];
    if (failTransfer)
      throw const GroupException(
        GroupFailure(GroupFailureType.invalidOwnershipTarget),
      );
    return _detail(owner: q.newOwnerUserId, role: GroupRole.admin);
  }

  @override
  Future<GroupSettings> updateSettings(
    String id,
    UpdateGroupSettingsRequest q,
  ) async {
    settingsRequest = q;
    return _settings();
  }

  @override
  Future<GroupSettings> getSettings(String id) async => _settings();
}

GroupDetail _detail({
  String owner = 'owner',
  GroupRole role = GroupRole.owner,
}) => GroupDetail(
  id: 'g',
  name: 'G',
  status: GroupStatus.active,
  ownerUserId: owner,
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
GroupSettings _settings() => GroupSettings(
  groupId: 'g',
  joinPolicy: GroupJoinPolicy.autoJoin,
  memberModifyInfoAllowed: false,
  memberCreateActivityAllowed: false,
  memberPinMessageAllowed: false,
  chatHistoryPolicy: ChatHistoryPolicy.fullHistory,
  updatedAt: DateTime(2026),
);
