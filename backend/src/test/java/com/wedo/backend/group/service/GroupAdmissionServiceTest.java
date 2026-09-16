package com.wedo.backend.group.service;

import com.wedo.backend.common.dto.PagedResponse;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.group.dto.CreateInvitationRequest;
import com.wedo.backend.group.dto.CreateInviteLinkRequest;
import com.wedo.backend.group.dto.GroupInvitationResponse;
import com.wedo.backend.group.dto.GroupInviteSummaryResponse;
import com.wedo.backend.group.dto.InviteLinkResponse;
import com.wedo.backend.group.dto.JoinRequestResponse;
import com.wedo.backend.group.entity.GroupActivityLogEntity;
import com.wedo.backend.group.entity.GroupEntity;
import com.wedo.backend.group.entity.GroupInvitationEntity;
import com.wedo.backend.group.entity.GroupInvitationStatus;
import com.wedo.backend.group.entity.GroupInviteLinkEntity;
import com.wedo.backend.group.entity.GroupJoinPolicy;
import com.wedo.backend.group.entity.GroupJoinRequestEntity;
import com.wedo.backend.group.entity.GroupJoinRequestStatus;
import com.wedo.backend.group.entity.GroupMembershipEntity;
import com.wedo.backend.group.entity.GroupMembershipStatus;
import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.entity.GroupSettingsEntity;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.group.repository.GroupActivityLogRepository;
import com.wedo.backend.group.repository.GroupBanRepository;
import com.wedo.backend.group.repository.GroupInvitationRepository;
import com.wedo.backend.group.repository.GroupInviteLinkRepository;
import com.wedo.backend.group.repository.GroupJoinRequestRepository;
import com.wedo.backend.group.repository.GroupMembershipRepository;
import com.wedo.backend.group.repository.GroupRepository;
import com.wedo.backend.group.repository.GroupSettingsRepository;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.repository.UserRepository;
import com.wedo.backend.user.service.UserService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class GroupAdmissionServiceTest {

    private static final Instant NOW = Instant.parse("2026-09-15T12:00:00Z");
    private final Clock clock = Clock.fixed(NOW, ZoneOffset.UTC);

    @Mock private GroupRepository groupRepository;
    @Mock private GroupSettingsRepository groupSettingsRepository;
    @Mock private GroupMembershipRepository groupMembershipRepository;
    @Mock private GroupActivityLogRepository groupActivityLogRepository;
    @Mock private GroupInvitationRepository groupInvitationRepository;
    @Mock private GroupInviteLinkRepository groupInviteLinkRepository;
    @Mock private GroupJoinRequestRepository groupJoinRequestRepository;
    @Mock private GroupBanRepository groupBanRepository;
    @Mock private UserRepository userRepository;
    @Mock private UserService userService;
    @Mock private GroupPermissionService groupPermissionService;

    private GroupAdmissionService admissionService;

    @BeforeEach
    void setUp() {
        admissionService = new GroupAdmissionService(
                groupRepository,
                groupSettingsRepository,
                groupMembershipRepository,
                groupActivityLogRepository,
                groupInvitationRepository,
                groupInviteLinkRepository,
                groupJoinRequestRepository,
                groupBanRepository,
                userRepository,
                userService,
                groupPermissionService,
                clock
        );
    }

    @Test
    void createInvitation_happyPath() {
        UUID groupId = UUID.randomUUID();
        UUID callerId = UUID.randomUUID();
        UUID inviteeId = UUID.randomUUID();

        GroupEntity group = new GroupEntity(groupId, "Test Group", "Desc", null, GroupStatus.ACTIVE, callerId, NOW, NOW);
        GroupMembershipEntity callerMembership = new GroupMembershipEntity(UUID.randomUUID(), groupId, callerId, GroupRole.OWNER, GroupMembershipStatus.ACTIVE, NOW, null);

        when(groupPermissionService.requireAdminOrOwner(groupId, callerId)).thenReturn(new ReadableGroupAccess(group, callerMembership));
        when(groupBanRepository.existsByGroupIdAndUserIdAndUnbannedAtIsNull(groupId, inviteeId)).thenReturn(false);
        when(groupMembershipRepository.findFirstByGroupIdAndUserIdAndStatus(groupId, inviteeId, GroupMembershipStatus.ACTIVE)).thenReturn(Optional.empty());
        when(groupInvitationRepository.existsByGroupIdAndInviteeIdAndStatus(groupId, inviteeId, GroupInvitationStatus.PENDING)).thenReturn(false);
        when(groupInvitationRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        GroupInvitationResponse response = admissionService.createInvitation(groupId, callerId, new CreateInvitationRequest(inviteeId));

        assertNotNull(response);
        assertEquals(groupId, response.groupId());
        assertEquals(inviteeId, response.inviteeId());
        assertEquals(GroupInvitationStatus.PENDING, response.status());
        verify(userService).requireActiveUser(inviteeId);
    }

    @Test
    void createInvitation_cannotInviteSelf() {
        UUID groupId = UUID.randomUUID();
        UUID callerId = UUID.randomUUID();

        GroupEntity group = new GroupEntity(groupId, "Test Group", "Desc", null, GroupStatus.ACTIVE, callerId, NOW, NOW);
        GroupMembershipEntity callerMembership = new GroupMembershipEntity(UUID.randomUUID(), groupId, callerId, GroupRole.OWNER, GroupMembershipStatus.ACTIVE, NOW, null);

        when(groupPermissionService.requireAdminOrOwner(groupId, callerId)).thenReturn(new ReadableGroupAccess(group, callerMembership));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> admissionService.createInvitation(groupId, callerId, new CreateInvitationRequest(callerId)));
        assertEquals(ErrorCode.CANNOT_INVITE_SELF, ex.errorCode());
    }

    @Test
    void createInvitation_bannedUserDenied() {
        UUID groupId = UUID.randomUUID();
        UUID callerId = UUID.randomUUID();
        UUID inviteeId = UUID.randomUUID();

        GroupEntity group = new GroupEntity(groupId, "Test Group", "Desc", null, GroupStatus.ACTIVE, callerId, NOW, NOW);
        GroupMembershipEntity callerMembership = new GroupMembershipEntity(UUID.randomUUID(), groupId, callerId, GroupRole.OWNER, GroupMembershipStatus.ACTIVE, NOW, null);

        when(groupPermissionService.requireAdminOrOwner(groupId, callerId)).thenReturn(new ReadableGroupAccess(group, callerMembership));
        when(groupBanRepository.existsByGroupIdAndUserIdAndUnbannedAtIsNull(groupId, inviteeId)).thenReturn(true);

        BusinessException ex = assertThrows(BusinessException.class,
                () -> admissionService.createInvitation(groupId, callerId, new CreateInvitationRequest(inviteeId)));
        assertEquals(ErrorCode.USER_BANNED_FROM_GROUP, ex.errorCode());
    }

    @Test
    void acceptInvitation_capacityLimitReached() {
        UUID invitationId = UUID.randomUUID();
        UUID groupId = UUID.randomUUID();
        UUID inviteeId = UUID.randomUUID();

        GroupInvitationEntity invitation = new GroupInvitationEntity(invitationId, groupId, UUID.randomUUID(), inviteeId, GroupInvitationStatus.PENDING, NOW, null);
        when(groupInvitationRepository.findById(invitationId)).thenReturn(Optional.of(invitation));

        GroupEntity group = new GroupEntity(groupId, "Test Group", "Desc", null, GroupStatus.ACTIVE, UUID.randomUUID(), NOW, NOW);
        when(groupRepository.findByIdForUpdate(groupId)).thenReturn(Optional.of(group));
        when(groupBanRepository.existsByGroupIdAndUserIdAndUnbannedAtIsNull(groupId, inviteeId)).thenReturn(false);
        when(groupMembershipRepository.findFirstByGroupIdAndUserIdAndStatus(groupId, inviteeId, GroupMembershipStatus.ACTIVE)).thenReturn(Optional.empty());
        when(groupMembershipRepository.countByGroupIdAndStatus(groupId, GroupMembershipStatus.ACTIVE)).thenReturn(100L);

        BusinessException ex = assertThrows(BusinessException.class, () -> admissionService.acceptInvitation(invitationId, inviteeId));
        assertEquals(ErrorCode.GROUP_MEMBER_LIMIT_REACHED, ex.errorCode());
        assertEquals(GroupInvitationStatus.PENDING, invitation.getStatus());
    }

    @Test
    void acceptInvitation_successCreatesActiveMembership() {
        UUID invitationId = UUID.randomUUID();
        UUID groupId = UUID.randomUUID();
        UUID inviteeId = UUID.randomUUID();

        GroupInvitationEntity invitation = new GroupInvitationEntity(invitationId, groupId, UUID.randomUUID(), inviteeId, GroupInvitationStatus.PENDING, NOW, null);
        when(groupInvitationRepository.findById(invitationId)).thenReturn(Optional.of(invitation));

        GroupEntity group = new GroupEntity(groupId, "Test Group", "Desc", null, GroupStatus.ACTIVE, UUID.randomUUID(), NOW, NOW);
        when(groupRepository.findByIdForUpdate(groupId)).thenReturn(Optional.of(group));
        when(groupBanRepository.existsByGroupIdAndUserIdAndUnbannedAtIsNull(groupId, inviteeId)).thenReturn(false);
        when(groupMembershipRepository.findFirstByGroupIdAndUserIdAndStatus(groupId, inviteeId, GroupMembershipStatus.ACTIVE)).thenReturn(Optional.empty());
        when(groupMembershipRepository.countByGroupIdAndStatus(groupId, GroupMembershipStatus.ACTIVE)).thenReturn(42L);
        when(groupMembershipRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        admissionService.acceptInvitation(invitationId, inviteeId);

        assertEquals(GroupInvitationStatus.ACCEPTED, invitation.getStatus());
        assertEquals(NOW, invitation.getRespondedAt());

        ArgumentCaptor<GroupMembershipEntity> membershipCaptor = ArgumentCaptor.forClass(GroupMembershipEntity.class);
        verify(groupMembershipRepository).save(membershipCaptor.capture());
        assertEquals(GroupRole.MEMBER, membershipCaptor.getValue().getRole());
        assertEquals(GroupMembershipStatus.ACTIVE, membershipCaptor.getValue().getStatus());
        verify(groupActivityLogRepository).save(any());
    }

    @Test
    void declineInvitation_happyPath() {
        UUID invitationId = UUID.randomUUID();
        UUID inviteeId = UUID.randomUUID();

        GroupInvitationEntity invitation = new GroupInvitationEntity(invitationId, UUID.randomUUID(), UUID.randomUUID(), inviteeId, GroupInvitationStatus.PENDING, NOW, null);
        when(groupInvitationRepository.findById(invitationId)).thenReturn(Optional.of(invitation));

        admissionService.declineInvitation(invitationId, inviteeId);

        assertEquals(GroupInvitationStatus.DECLINED, invitation.getStatus());
        assertEquals(NOW, invitation.getRespondedAt());
    }

    @Test
    void joinViaInviteCode_autoJoinSuccess() {
        UUID groupId = UUID.randomUUID();
        UUID callerId = UUID.randomUUID();
        String code = "valid-code-123";

        GroupInviteLinkEntity link = new GroupInviteLinkEntity(UUID.randomUUID(), groupId, code, UUID.randomUUID(), 10, 2, null, false, NOW);
        when(groupInviteLinkRepository.findIdentityByCode(code)).thenReturn(Optional.of(identity(link)));

        GroupEntity group = new GroupEntity(groupId, "Test Group", "Desc", null, GroupStatus.ACTIVE, UUID.randomUUID(), NOW, NOW);
        when(groupRepository.findByIdForUpdate(groupId)).thenReturn(Optional.of(group));
        when(groupInviteLinkRepository.findByIdForUpdate(link.getId())).thenReturn(Optional.of(link));
        when(groupBanRepository.existsByGroupIdAndUserIdAndUnbannedAtIsNull(groupId, callerId)).thenReturn(false);
        when(groupMembershipRepository.findFirstByGroupIdAndUserIdAndStatus(groupId, callerId, GroupMembershipStatus.ACTIVE)).thenReturn(Optional.empty());
        when(groupMembershipRepository.countByGroupIdAndStatus(groupId, GroupMembershipStatus.ACTIVE)).thenReturn(10L);

        GroupSettingsEntity settings = GroupSettingsEntity.createDefault(groupId, NOW);
        when(groupSettingsRepository.findById(groupId)).thenReturn(Optional.of(settings));

        admissionService.joinViaInviteCode(code, callerId);

        assertEquals(3, link.getUsesCount());
        verify(groupMembershipRepository).save(any());
    }

    @Test
    void joinViaInviteCode_approvalRequiredCreatesJoinRequest() {
        UUID groupId = UUID.randomUUID();
        UUID callerId = UUID.randomUUID();
        String code = "valid-code-approval";

        GroupInviteLinkEntity link = new GroupInviteLinkEntity(UUID.randomUUID(), groupId, code, UUID.randomUUID(), null, 0, null, false, NOW);
        when(groupInviteLinkRepository.findIdentityByCode(code)).thenReturn(Optional.of(identity(link)));

        GroupEntity group = new GroupEntity(groupId, "Approval Group", "Desc", null, GroupStatus.ACTIVE, UUID.randomUUID(), NOW, NOW);
        when(groupRepository.findByIdForUpdate(groupId)).thenReturn(Optional.of(group));
        when(groupInviteLinkRepository.findByIdForUpdate(link.getId())).thenReturn(Optional.of(link));
        when(groupBanRepository.existsByGroupIdAndUserIdAndUnbannedAtIsNull(groupId, callerId)).thenReturn(false);
        when(groupMembershipRepository.findFirstByGroupIdAndUserIdAndStatus(groupId, callerId, GroupMembershipStatus.ACTIVE)).thenReturn(Optional.empty());

        GroupSettingsEntity settings = new GroupSettingsEntity(groupId, GroupJoinPolicy.APPROVAL_REQUIRED, false, true, false, com.wedo.backend.group.entity.ChatHistoryPolicy.FULL_HISTORY, NOW, NOW);
        when(groupSettingsRepository.findById(groupId)).thenReturn(Optional.of(settings));
        when(groupJoinRequestRepository.existsByGroupIdAndUserIdAndStatus(groupId, callerId, GroupJoinRequestStatus.PENDING)).thenReturn(false);
        when(groupJoinRequestRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        Object result = admissionService.joinViaInviteCode(code, callerId);

        assertTrue(result instanceof JoinRequestResponse);
        assertEquals(0, link.getUsesCount()); // Must NOT increment usesCount
        verify(groupMembershipRepository, never()).save(any());
    }

    @Test
    void approveJoinRequest_happyPath() {
        UUID requestId = UUID.randomUUID();
        UUID groupId = UUID.randomUUID();
        UUID targetUserId = UUID.randomUUID();
        UUID callerId = UUID.randomUUID();

        GroupJoinRequestEntity request = new GroupJoinRequestEntity(requestId, groupId, targetUserId, GroupJoinRequestStatus.PENDING, NOW, null, null);
        when(groupJoinRequestRepository.findById(requestId)).thenReturn(Optional.of(request));

        GroupEntity group = new GroupEntity(groupId, "Test Group", "Desc", null, GroupStatus.ACTIVE, callerId, NOW, NOW);
        when(groupRepository.findByIdForUpdate(groupId)).thenReturn(Optional.of(group));
        when(groupBanRepository.existsByGroupIdAndUserIdAndUnbannedAtIsNull(groupId, targetUserId)).thenReturn(false);
        when(groupMembershipRepository.findFirstByGroupIdAndUserIdAndStatus(groupId, targetUserId, GroupMembershipStatus.ACTIVE)).thenReturn(Optional.empty());
        when(groupMembershipRepository.countByGroupIdAndStatus(groupId, GroupMembershipStatus.ACTIVE)).thenReturn(5L);

        admissionService.approveJoinRequest(requestId, callerId);

        assertEquals(GroupJoinRequestStatus.APPROVED, request.getStatus());
        assertEquals(callerId, request.getRespondedBy());
        verify(groupMembershipRepository).save(any());
    }

    private GroupInviteLinkRepository.InviteLinkIdentity identity(GroupInviteLinkEntity link) {
        return new GroupInviteLinkRepository.InviteLinkIdentity() {
            @Override public UUID getId() { return link.getId(); }
            @Override public UUID getGroupId() { return link.getGroupId(); }
        };
    }
}
