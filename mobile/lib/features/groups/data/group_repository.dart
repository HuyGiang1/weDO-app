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
}
