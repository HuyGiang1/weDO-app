import '../../../core/models/paged_response.dart';
import '../../../core/network/api_exception.dart';
import 'group_api.dart';
import 'group_failure.dart';
import 'models/group_models.dart';

class GroupRepository {
  final GroupApi api;
  GroupRepository({required this.api});
  Future<T> _guard<T>(Future<T> Function() w) async {
    try {
      return await w();
    } on ApiException catch (e) {
      throw GroupException(GroupFailure.fromApi(e));
    } catch (e) {
      if (e is GroupException) rethrow;
      throw const GroupException(GroupFailure(GroupFailureType.unknown));
    }
  }

  Future<PagedResponse<GroupSummary>> listGroups({
    int page = 0,
    int size = 30,
    GroupStatus status = GroupStatus.active,
  }) => _guard(() => api.listGroups(page: page, size: size, status: status));
  Future<PagedResponse<GroupActivityLog>> getActivityLogs(
    String id, {
    int page = 0,
    int size = 30,
  }) => _guard(() => api.getActivityLogs(id, page: page, size: size));
  Future<CreatedGroup> createGroup(CreateGroupRequest q) =>
      _guard(() => api.create(q));
  Future<GroupDetail> getGroup(String id) => _guard(() => api.getGroup(id));
  Future<List<GroupMember>> getMembers(String id) =>
      _guard(() => api.getMembers(id));
  Future<GroupMember> getMember(String id, String u) =>
      _guard(() => api.getMember(id, u));
  Future<GroupDetail> updateGroup(String id, UpdateGroupRequest q) =>
      _guard(() => api.updateGroup(id, q));
  Future<GroupSettings> getSettings(String id) =>
      _guard(() => api.getSettings(id));
  Future<GroupSettings> updateSettings(
    String id,
    UpdateGroupSettingsRequest q,
  ) => _guard(() => api.updateSettings(id, q));
  Future<GroupMember> promoteAdmin(String id, String u) =>
      _guard(() => api.promote(id, u));
  Future<GroupMember> demoteAdmin(String id, String u) =>
      _guard(() => api.demote(id, u));
  Future<void> kickMember(String id, String u) => _guard(() => api.kick(id, u));
  Future<void> leaveGroup(String id) => _guard(() => api.leave(id));
  Future<GroupDetail> transferOwnership(
    String id,
    TransferOwnershipRequest q,
  ) => _guard(() => api.transfer(id, q));

  // M6: Invitations
  Future<GroupInvitationResponse> createInvitation(
    String groupId,
    CreateInvitationRequest q,
  ) => _guard(() => api.createInvitation(groupId, q));

  Future<PagedResponse<GroupInvitationResponse>> listMyInvitations({
    int page = 0,
    int size = 20,
    String status = 'PENDING',
  }) => _guard(() => api.listMyInvitations(page: page, size: size, status: status));

  Future<void> acceptInvitation(String id) =>
      _guard(() => api.acceptInvitation(id));

  Future<void> declineInvitation(String id) =>
      _guard(() => api.declineInvitation(id));

  Future<void> cancelInvitation(String id) =>
      _guard(() => api.cancelInvitation(id));

  // M6: Invite Links
  Future<InviteLinkResponse> createInviteLink(
    String groupId,
    CreateInviteLinkRequest q,
  ) => _guard(() => api.createInviteLink(groupId, q));

  Future<List<InviteLinkResponse>> listInviteLinks(String groupId) =>
      _guard(() => api.listInviteLinks(groupId));

  Future<void> revokeInviteLink(String id) =>
      _guard(() => api.revokeInviteLink(id));

  Future<GroupInviteSummaryResponse> resolveInviteCode(String code) =>
      _guard(() => api.resolveInviteCode(code));

  Future<void> joinViaInviteCode(String code) =>
      _guard(() => api.joinViaInviteCode(code));

  // M6: Join Requests
  Future<PagedResponse<JoinRequestResponse>> listJoinRequests(
    String groupId, {
    int page = 0,
    int size = 20,
  }) => _guard(() => api.listJoinRequests(groupId, page: page, size: size));

  Future<void> approveJoinRequest(String requestId) =>
      _guard(() => api.approveJoinRequest(requestId));

  Future<void> rejectJoinRequest(String requestId) =>
      _guard(() => api.rejectJoinRequest(requestId));

  Future<void> cancelJoinRequest(String requestId) =>
      _guard(() => api.cancelJoinRequest(requestId));

  // M6: Bans
  Future<GroupBanResponse> banMember(
    String groupId,
    String userId,
    BanMemberRequest q,
  ) => _guard(() => api.banMember(groupId, userId, q));

  Future<PagedResponse<GroupBanResponse>> listBans(
    String groupId, {
    int page = 0,
    int size = 30,
  }) => _guard(() => api.listBans(groupId, page: page, size: size));

  Future<void> unbanUser(String groupId, String userId) =>
      _guard(() => api.unbanUser(groupId, userId));

  // M6: Lifecycle
  Future<void> archiveGroup(String groupId) =>
      _guard(() => api.archiveGroup(groupId));

  Future<void> restoreGroup(String groupId) =>
      _guard(() => api.restoreGroup(groupId));

  Future<void> deleteGroup(String groupId) =>
      _guard(() => api.deleteGroup(groupId));
}
