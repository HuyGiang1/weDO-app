import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import 'app/theme/app_colors.dart';
import 'core/models/paged_response.dart';

// Social
import 'features/social/application/social_controllers.dart';
import 'features/social/data/models/social_models.dart';
import 'features/social/data/social_api.dart';
import 'features/social/data/social_repository.dart';
import 'features/social/presentation/screens/blocked_users_screen.dart';
import 'features/social/presentation/screens/friend_requests_screen.dart';
import 'features/social/presentation/screens/friends_screen.dart';

// Groups
import 'features/groups/application/group_admission_controllers.dart';
import 'features/groups/application/group_detail_controller.dart';
import 'features/groups/application/groups_controller.dart';
import 'features/groups/data/group_api.dart';
import 'features/groups/data/group_repository.dart';
import 'features/groups/data/models/group_models.dart';
import 'features/groups/presentation/screens/group_admission_screens.dart';
import 'features/groups/presentation/screens/group_info_screen.dart';
import 'features/groups/presentation/screens/my_groups_screen.dart';

// ============================================================================
// DEMO REPOSITORIES (In-Memory Interactive Mock)
// ============================================================================

class DemoGroupRepository extends GroupRepository {
  DemoGroupRepository() : super(api: GroupApi(Dio()));

  final List<GroupSummary> _groups = [
    GroupSummary(
      id: 'group-1',
      name: 'weDO Core Engineering',
      status: GroupStatus.active,
      callerRole: GroupRole.owner,
      updatedAt: DateTime.now().subtract(const Duration(minutes: 15)),
    ),
    GroupSummary(
      id: 'group-2',
      name: 'CLB Cầu Lông Sài Gòn',
      status: GroupStatus.active,
      callerRole: GroupRole.admin,
      updatedAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    GroupSummary(
      id: 'group-3',
      name: 'Boardgame Weekend',
      status: GroupStatus.active,
      callerRole: GroupRole.member,
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  final List<GroupInvitationResponse> _invitations = [
    GroupInvitationResponse(
      id: 'inv-1',
      groupId: 'Morning Runners Club',
      inviterUserId: 'Alex Rivera',
      inviteeUserId: 'current-user',
      status: GroupInvitationStatus.pending,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    GroupInvitationResponse(
      id: 'inv-2',
      groupId: 'Design Guild Global',
      inviterUserId: 'Elena Rostova',
      inviteeUserId: 'current-user',
      status: GroupInvitationStatus.pending,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  final List<JoinRequestResponse> _joinRequests = [
    JoinRequestResponse(
      id: 'req-1',
      groupId: 'group-1',
      requesterUserId: 'Nguyễn Mai Anh (@maianh.dev)',
      status: GroupJoinRequestStatus.pending,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    JoinRequestResponse(
      id: 'req-2',
      groupId: 'group-1',
      requesterUserId: 'Alex Rivera (@arivera)',
      status: GroupJoinRequestStatus.pending,
      createdAt: DateTime.now().subtract(const Duration(hours: 7)),
    ),
  ];

  final List<InviteLinkResponse> _inviteLinks = [
    InviteLinkResponse(
      id: 'link-1',
      groupId: 'group-1',
      inviteCode: 'RUN-2024',
      creatorUserId: 'u-owner',
      isRevoked: false,
      usesCount: 12,
      maxUses: 50,
      expiresAt: DateTime.now().add(const Duration(days: 7)),
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    InviteLinkResponse(
      id: 'link-2',
      groupId: 'group-1',
      inviteCode: 'DESIGN99',
      creatorUserId: 'u-owner',
      isRevoked: false,
      usesCount: 8,
      maxUses: 20,
      expiresAt: DateTime.now().add(const Duration(days: 14)),
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];

  final List<GroupBanResponse> _bans = [
    GroupBanResponse(
      id: 'ban-1',
      groupId: 'group-1',
      bannedUserId: 'Trần Tuấn Kiệt (@kiet.tran)',
      bannedByUserId: 'u-admin',
      reason: 'Spam liên kết quảng cáo không hợp lệ',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    GroupBanResponse(
      id: 'ban-2',
      groupId: 'group-1',
      bannedUserId: 'Emily Watson (@emily_w)',
      bannedByUserId: 'u-owner',
      reason: 'Vi phạm quy tắc ứng xử cộng đồng',
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    ),
  ];

  @override
  Future<PagedResponse<GroupSummary>> listGroups({
    int page = 0,
    int size = 30,
    GroupStatus status = GroupStatus.active,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return PagedResponse(
      items: List.unmodifiable(_groups),
      page: page,
      size: size,
      totalElements: _groups.length,
      totalPages: 1,
      hasNext: false,
    );
  }

  @override
  Future<GroupDetail> getGroup(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return GroupDetail(
      id: id,
      name: 'Design Guild',
      description: 'A community of passionate designers, researchers, and creative minds collaborating on impactful digital products and design systems.',
      status: GroupStatus.active,
      ownerUserId: 'u-owner',
      callerRole: GroupRole.owner,
      createdAt: DateTime(2023, 10, 1),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<PagedResponse<GroupInvitationResponse>> listMyInvitations({
    int page = 0,
    int size = 20,
    String status = 'PENDING',
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return PagedResponse(
      items: List.unmodifiable(_invitations),
      page: page,
      size: size,
      totalElements: _invitations.length,
      totalPages: 1,
      hasNext: false,
    );
  }

  @override
  Future<void> acceptInvitation(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _invitations.removeWhere((i) => i.id == id);
  }

  @override
  Future<void> declineInvitation(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _invitations.removeWhere((i) => i.id == id);
  }

  @override
  Future<GroupInviteSummaryResponse> resolveInviteCode(String code) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return GroupInviteSummaryResponse(
      groupId: 'group-resolved-1',
      groupName: 'Cộng đồng Lập trình viên weDO',
      groupDescription: 'Nơi giao lưu, trao đổi kinh nghiệm công nghệ.',
      activeMemberCount: 42,
      joinPolicy: code.toUpperCase().contains('REQ')
          ? GroupJoinPolicy.approvalRequired
          : GroupJoinPolicy.autoJoin,
    );
  }

  @override
  Future<void> joinViaInviteCode(String code) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<PagedResponse<JoinRequestResponse>> listJoinRequests(
    String groupId, {
    int page = 0,
    int size = 20,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return PagedResponse(
      items: List.unmodifiable(_joinRequests),
      page: page,
      size: size,
      totalElements: _joinRequests.length,
      totalPages: 1,
      hasNext: false,
    );
  }

  @override
  Future<void> approveJoinRequest(String requestId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _joinRequests.removeWhere((r) => r.id == requestId);
  }

  @override
  Future<void> rejectJoinRequest(String requestId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _joinRequests.removeWhere((r) => r.id == requestId);
  }

  @override
  Future<List<InviteLinkResponse>> listInviteLinks(String groupId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return List.unmodifiable(_inviteLinks);
  }

  @override
  Future<InviteLinkResponse> createInviteLink(
    String groupId,
    CreateInviteLinkRequest q,
  ) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final newLink = InviteLinkResponse(
      id: 'link-${DateTime.now().millisecondsSinceEpoch}',
      groupId: groupId,
      inviteCode: 'NEW${DateTime.now().millisecondsSinceEpoch % 10000}',
      creatorUserId: 'u-owner',
      isRevoked: false,
      usesCount: 0,
      maxUses: q.maxUses,
      expiresAt: q.expiresAt,
      createdAt: DateTime.now(),
    );
    _inviteLinks.insert(0, newLink);
    return newLink;
  }

  @override
  Future<void> revokeInviteLink(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _inviteLinks.removeWhere((l) => l.id == id);
  }

  @override
  Future<PagedResponse<GroupBanResponse>> listBans(
    String groupId, {
    int page = 0,
    int size = 30,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return PagedResponse(
      items: List.unmodifiable(_bans),
      page: page,
      size: size,
      totalElements: _bans.length,
      totalPages: 1,
      hasNext: false,
    );
  }

  @override
  Future<void> unbanUser(String groupId, String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _bans.removeWhere((b) => b.bannedUserId == userId);
  }

  @override
  Future<void> archiveGroup(String groupId) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<void> restoreGroup(String groupId) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _groups.removeWhere((g) => g.id == groupId);
  }
}

class DemoSocialRepository extends SocialRepository {
  DemoSocialRepository() : super(api: SocialApi(Dio()));

  final List<Friend> _friends = [
    Friend(
      friendshipId: 'f-1',
      friend: const SocialUserSummary(
        id: 'u-1',
        username: 'lan.anh',
        displayName: 'Lan Anh',
      ),
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    ),
    Friend(
      friendshipId: 'f-2',
      friend: const SocialUserSummary(
        id: 'u-2',
        username: 'minh.tri',
        displayName: 'Minh Trí',
      ),
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    Friend(
      friendshipId: 'f-3',
      friend: const SocialUserSummary(
        id: 'u-3',
        username: 'hoang.nam',
        displayName: 'Hoàng Nam',
      ),
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  final List<FriendRequest> _received = [
    FriendRequest(
      id: 'req-rec-1',
      sender: const SocialUserSummary(
        id: 'u-4',
        username: 'thu.ha',
        displayName: 'Thu Hà',
      ),
      receiver: const SocialUserSummary(
        id: 'current-user',
        username: 'demo_user',
        displayName: 'Current User',
      ),
      status: FriendRequestStatus.pending,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    FriendRequest(
      id: 'req-rec-2',
      sender: const SocialUserSummary(
        id: 'u-5',
        username: 'quang.huy',
        displayName: 'Quang Huy',
      ),
      receiver: const SocialUserSummary(
        id: 'current-user',
        username: 'demo_user',
        displayName: 'Current User',
      ),
      status: FriendRequestStatus.pending,
      createdAt: DateTime.now().subtract(const Duration(hours: 8)),
    ),
  ];

  final List<BlockedUser> _blocked = [
    BlockedUser(
      blockId: 'b-1',
      blockedUser: const SocialUserSummary(
        id: 'u-bad-1',
        username: 'spammer_01',
        displayName: 'Spammer Bot',
      ),
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    BlockedUser(
      blockId: 'b-2',
      blockedUser: const SocialUserSummary(
        id: 'u-bad-2',
        username: 'toxic_guy',
        displayName: 'Tài khoản Vi phạm',
      ),
      createdAt: DateTime.now().subtract(const Duration(days: 12)),
    ),
  ];

  @override
  Future<PagedResponse<Friend>> getFriends({int page = 0, int size = 30}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return PagedResponse(
      items: List.unmodifiable(_friends),
      page: page,
      size: size,
      totalElements: _friends.length,
      totalPages: 1,
      hasNext: false,
    );
  }

  @override
  Future<void> unfriend(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _friends.removeWhere((f) => f.friend.id == userId);
  }

  @override
  Future<PagedResponse<FriendRequest>> getReceivedFriendRequests({int page = 0, int size = 30}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return PagedResponse(
      items: List.unmodifiable(_received),
      page: page,
      size: size,
      totalElements: _received.length,
      totalPages: 1,
      hasNext: false,
    );
  }

  @override
  Future<PagedResponse<FriendRequest>> getSentFriendRequests({int page = 0, int size = 30}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return PagedResponse(
      items: const [],
      page: page,
      size: size,
      totalElements: 0,
      totalPages: 0,
      hasNext: false,
    );
  }

  @override
  Future<FriendRequest> acceptFriendRequest(String requestId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final item = _received.firstWhere(
      (r) => r.id == requestId,
      orElse: () => _received.first,
    );
    _received.removeWhere((r) => r.id == requestId);
    return item;
  }

  @override
  Future<void> declineFriendRequest(String requestId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _received.removeWhere((r) => r.id == requestId);
  }

  @override
  Future<PagedResponse<BlockedUser>> getBlockedUsers({int page = 0, int size = 30}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return PagedResponse(
      items: List.unmodifiable(_blocked),
      page: page,
      size: size,
      totalElements: _blocked.length,
      totalPages: 1,
      hasNext: false,
    );
  }

  @override
  Future<void> unblockUser(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _blocked.removeWhere((b) => b.blockedUser.id == userId);
  }
}

// ============================================================================
// SHOWCASE HUB SCREEN
// ============================================================================

class DevShowcaseHubScreen extends StatelessWidget {
  final DemoGroupRepository groupRepo;
  final DemoSocialRepository socialRepo;

  const DevShowcaseHubScreen({
    super.key,
    required this.groupRepo,
    required this.socialRepo,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'weDO — Dev Showcase Hub',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Kiểm tra nhanh các giao diện M6 & M4 đã phát triển',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // Section M6
          _buildSectionHeader(
            context,
            title: '🌟 Milestone M6 — Group Lifecycle & Admission (Mới làm)',
            subtitle: 'Lời mời, tham gia bằng mã, duyệt yêu cầu, link mời, cấm & vòng đời nhóm',
            badgeColor: Colors.purple.shade700,
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            context,
            icon: Icons.mail_outline,
            color: Colors.indigo,
            title: 'Lời mời vào nhóm (Group Invitations)',
            subtitle: 'Xem lời mời được nhận, Chấp nhận (Accept) / Từ chối (Decline)',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MyGroupInvitationsScreen(
                    controller: GroupInvitationsController(groupRepo),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _buildActionCard(
            context,
            icon: Icons.vpn_key_outlined,
            color: Colors.blue.shade700,
            title: 'Tham gia bằng mã (Join by Code)',
            subtitle: 'Nhập mã mời (thử WEDO2026 hoặc REQ1234) -> Xem preview -> Tham gia',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => JoinByInviteCodeScreen(
                    controller: JoinByCodeController(groupRepo),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _buildActionCard(
            context,
            icon: Icons.how_to_reg_outlined,
            color: Colors.teal.shade700,
            title: 'Duyệt yêu cầu tham gia (Join Requests)',
            subtitle: 'Admin xem danh sách yêu cầu xin vào nhóm, Duyệt (Approve) hoặc Từ chối',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GroupJoinRequestsScreen(
                    groupId: 'group-1',
                    controller: JoinRequestsController(groupRepo),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _buildActionCard(
            context,
            icon: Icons.link_rounded,
            color: Colors.orange.shade800,
            title: 'Quản lý liên kết mời (Invite Links)',
            subtitle: 'Tạo link mời mới, thiết lập giới hạn lượt dùng, thu hồi link',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GroupInviteLinksScreen(
                    groupId: 'group-1',
                    controller: InviteLinksController(groupRepo),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _buildActionCard(
            context,
            icon: Icons.block_outlined,
            color: Colors.red.shade700,
            title: 'Danh sách thành viên bị cấm (Group Bans)',
            subtitle: 'Xem danh sách user bị cấm khỏi nhóm, lý do cấm, thao tác Gỡ cấm (Unban)',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GroupBansScreen(
                    groupId: 'group-1',
                    controller: GroupBansController(groupRepo),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _buildActionCard(
            context,
            icon: Icons.info_outline,
            color: Colors.purple.shade600,
            title: 'Thông tin nhóm & Quản trị M6 (Group Info)',
            subtitle: 'Màn hình chi tiết nhóm với các nút quản trị M6, Lưu trữ (Archive) & Xóa',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GroupInfoScreen(
                    groupId: 'group-1',
                    controller: GroupDetailController(groupRepo),
                    onEdit: () {},
                    onMembers: () {},
                    onSettings: () {},
                    onActivityLog: () {},
                    onLeave: () => Navigator.of(context).pop(),
                    onInviteLinks: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GroupInviteLinksScreen(
                            groupId: 'group-1',
                            controller: InviteLinksController(groupRepo),
                          ),
                        ),
                      );
                    },
                    onJoinRequests: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GroupJoinRequestsScreen(
                            groupId: 'group-1',
                            controller: JoinRequestsController(groupRepo),
                          ),
                        ),
                      );
                    },
                    onBans: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GroupBansScreen(
                            groupId: 'group-1',
                            controller: GroupBansController(groupRepo),
                          ),
                        ),
                      );
                    },
                    onArchive: () {},
                    onRestore: () {},
                    onDelete: () => Navigator.of(context).pop(),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _buildActionCard(
            context,
            icon: Icons.groups_outlined,
            color: Colors.blueGrey.shade800,
            title: 'Nhóm của tôi (My Groups Screen)',
            subtitle: 'Danh sách nhóm, nút nhanh Tham gia bằng mã & Lời mời vào nhóm',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MyGroupsScreen(
                    controller: GroupsController(groupRepo),
                    onCreate: () {},
                    onOpenGroup: (groupId) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GroupInfoScreen(
                            groupId: groupId,
                            controller: GroupDetailController(groupRepo),
                            onEdit: () {},
                            onMembers: () {},
                            onSettings: () {},
                            onActivityLog: () {},
                            onLeave: () => Navigator.of(context).pop(),
                          ),
                        ),
                      );
                    },
                    onInvitations: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MyGroupInvitationsScreen(
                            controller: GroupInvitationsController(groupRepo),
                          ),
                        ),
                      );
                    },
                    onJoinByCode: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => JoinByInviteCodeScreen(
                            controller: JoinByCodeController(groupRepo),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 30),

          // Section M4
          _buildSectionHeader(
            context,
            title: '👥 Milestone M4 — Social Screens (Đã port HTML)',
            subtitle: 'Giao diện Bạn bè, Lời mời kết bạn và Danh sách chặn',
            badgeColor: Colors.green.shade700,
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            context,
            icon: Icons.people_alt_outlined,
            color: Colors.blue,
            title: 'Danh sách bạn bè (Friends Screen)',
            subtitle: 'Hiển thị danh sách bạn bè, tìm kiếm, hủy kết bạn',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FriendsScreen(
                    controller: FriendsController(repository: socialRepo),
                    onOpenFriendRequests: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FriendRequestsScreen(
                            controller: FriendRequestsController(repository: socialRepo),
                          ),
                        ),
                      );
                    },
                    onOpenBlockedUsers: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BlockedUsersScreen(
                            controller: BlockedUsersController(repository: socialRepo),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _buildActionCard(
            context,
            icon: Icons.person_add_alt_1_outlined,
            color: Colors.deepPurple,
            title: 'Lời mời kết bạn (Friend Requests)',
            subtitle: 'Tab Đã nhận (Chấp nhận / Từ chối) & Tab Đã gửi',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FriendRequestsScreen(
                    controller: FriendRequestsController(repository: socialRepo),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _buildActionCard(
            context,
            icon: Icons.person_off_outlined,
            color: Colors.redAccent,
            title: 'Người dùng đã chặn (Blocked Users)',
            subtitle: 'Danh sách tài khoản đã chặn và thao tác bỏ chặn',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BlockedUsersScreen(
                    controller: BlockedUsersController(repository: socialRepo),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Color badgeColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: badgeColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0.8,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MAIN ENTRYPOINT
// ============================================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final groupRepo = DemoGroupRepository();
  final socialRepo = DemoSocialRepository();

  runApp(
    MaterialApp(
      title: 'weDO Dev Showcase Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F9FE),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
        ),
      ),
      home: DevShowcaseHubScreen(
        groupRepo: groupRepo,
        socialRepo: socialRepo,
      ),
    ),
  );
}
