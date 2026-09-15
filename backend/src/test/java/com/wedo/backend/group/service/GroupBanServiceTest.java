package com.wedo.backend.group.service;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.group.entity.GroupBanEntity;
import com.wedo.backend.group.entity.GroupEntity;
import com.wedo.backend.group.entity.GroupInvitationEntity;
import com.wedo.backend.group.entity.GroupInvitationStatus;
import com.wedo.backend.group.entity.GroupJoinRequestEntity;
import com.wedo.backend.group.entity.GroupJoinRequestStatus;
import com.wedo.backend.group.entity.GroupMembershipEntity;
import com.wedo.backend.group.entity.GroupMembershipStatus;
import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.group.repository.GroupActivityLogRepository;
import com.wedo.backend.group.repository.GroupBanRepository;
import com.wedo.backend.group.repository.GroupInvitationRepository;
import com.wedo.backend.group.repository.GroupJoinRequestRepository;
import com.wedo.backend.group.repository.GroupMembershipRepository;
import com.wedo.backend.group.repository.GroupRepository;
import com.wedo.backend.user.repository.UserRepository;
import com.wedo.backend.user.service.UserService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class GroupBanServiceTest {

    private static final Instant NOW = Instant.parse("2026-09-15T12:00:00Z");
    private final Clock clock = Clock.fixed(NOW, ZoneOffset.UTC);

    @Mock private GroupRepository groupRepository;
    @Mock private GroupMembershipRepository groupMembershipRepository;
    @Mock private GroupBanRepository groupBanRepository;
    @Mock private GroupInvitationRepository groupInvitationRepository;
    @Mock private GroupJoinRequestRepository groupJoinRequestRepository;
    @Mock private GroupActivityLogRepository groupActivityLogRepository;
    @Mock private UserRepository userRepository;
    @Mock private UserService userService;
    @Mock private GroupPermissionService groupPermissionService;

    private GroupBanService banService;

    @BeforeEach
    void setUp() {
        banService = new GroupBanService(
                groupRepository,
                groupMembershipRepository,
                groupBanRepository,
                groupInvitationRepository,
                groupJoinRequestRepository,
                groupActivityLogRepository,
                userRepository,
                userService,
                groupPermissionService,
                clock
        );
    }

    @Test
    void banMember_ownerBansMember_success() {
        UUID groupId = UUID.randomUUID();
        UUID ownerId = UUID.randomUUID();
        UUID targetId = UUID.randomUUID();

        GroupEntity group = new GroupEntity(groupId, "Test", "Desc", null, GroupStatus.ACTIVE, ownerId, NOW, NOW);
        when(groupRepository.findByIdForUpdate(groupId)).thenReturn(Optional.of(group));

        GroupMembershipEntity ownerMembership = new GroupMembershipEntity(UUID.randomUUID(), groupId, ownerId, GroupRole.OWNER, GroupMembershipStatus.ACTIVE, NOW, null);
        when(groupMembershipRepository.findActiveByGroupIdAndUserIdForUpdate(groupId, ownerId, GroupMembershipStatus.ACTIVE)).thenReturn(Optional.of(ownerMembership));

        GroupMembershipEntity memberMembership = new GroupMembershipEntity(UUID.randomUUID(), groupId, targetId, GroupRole.MEMBER, GroupMembershipStatus.ACTIVE, NOW, null);
        when(groupMembershipRepository.findActiveByGroupIdAndUserIdForUpdate(groupId, targetId, GroupMembershipStatus.ACTIVE)).thenReturn(Optional.of(memberMembership));

        when(groupBanRepository.existsByGroupIdAndUserIdAndUnbannedAtIsNull(groupId, targetId)).thenReturn(false);

        GroupInvitationEntity invitation = new GroupInvitationEntity(UUID.randomUUID(), groupId, ownerId, targetId, GroupInvitationStatus.PENDING, NOW, null);
        when(groupInvitationRepository.findByGroupIdAndInviteeId(groupId, targetId)).thenReturn(List.of(invitation));

        GroupJoinRequestEntity joinRequest = new GroupJoinRequestEntity(UUID.randomUUID(), groupId, targetId, GroupJoinRequestStatus.PENDING, NOW, null, null);
        when(groupJoinRequestRepository.findByGroupIdAndUserId(groupId, targetId)).thenReturn(List.of(joinRequest));

        banService.banMember(groupId, targetId, ownerId, "Spam");

        assertEquals(GroupMembershipStatus.BANNED, memberMembership.getStatus());
        assertEquals(NOW, memberMembership.getEndedAt());
        assertEquals(GroupInvitationStatus.CANCELLED, invitation.getStatus());
        assertEquals(GroupJoinRequestStatus.CANCELLED, joinRequest.getStatus());

        ArgumentCaptor<GroupBanEntity> banCaptor = ArgumentCaptor.forClass(GroupBanEntity.class);
        verify(groupBanRepository).save(banCaptor.capture());
        assertEquals("Spam", banCaptor.getValue().getReason());
        assertTrue(banCaptor.getValue().isActive());
        verify(groupActivityLogRepository).save(any());
    }

    @Test
    void banMember_adminCannotBanAdmin() {
        UUID groupId = UUID.randomUUID();
        UUID admin1Id = UUID.randomUUID();
        UUID admin2Id = UUID.randomUUID();

        GroupEntity group = new GroupEntity(groupId, "Test", "Desc", null, GroupStatus.ACTIVE, UUID.randomUUID(), NOW, NOW);
        when(groupRepository.findByIdForUpdate(groupId)).thenReturn(Optional.of(group));

        GroupMembershipEntity caller = new GroupMembershipEntity(UUID.randomUUID(), groupId, admin1Id, GroupRole.ADMIN, GroupMembershipStatus.ACTIVE, NOW, null);
        when(groupMembershipRepository.findActiveByGroupIdAndUserIdForUpdate(groupId, admin1Id, GroupMembershipStatus.ACTIVE)).thenReturn(Optional.of(caller));

        GroupMembershipEntity target = new GroupMembershipEntity(UUID.randomUUID(), groupId, admin2Id, GroupRole.ADMIN, GroupMembershipStatus.ACTIVE, NOW, null);
        when(groupMembershipRepository.findActiveByGroupIdAndUserIdForUpdate(groupId, admin2Id, GroupMembershipStatus.ACTIVE)).thenReturn(Optional.of(target));

        BusinessException ex = assertThrows(BusinessException.class, () -> banService.banMember(groupId, admin2Id, admin1Id, null));
        assertEquals(ErrorCode.CANNOT_BAN_ADMIN, ex.errorCode());
        verify(groupBanRepository, never()).save(any());
    }

    @Test
    void banMember_cannotBanOwner() {
        UUID groupId = UUID.randomUUID();
        UUID adminId = UUID.randomUUID();
        UUID ownerId = UUID.randomUUID();

        GroupEntity group = new GroupEntity(groupId, "Test", "Desc", null, GroupStatus.ACTIVE, ownerId, NOW, NOW);
        when(groupRepository.findByIdForUpdate(groupId)).thenReturn(Optional.of(group));

        GroupMembershipEntity caller = new GroupMembershipEntity(UUID.randomUUID(), groupId, adminId, GroupRole.ADMIN, GroupMembershipStatus.ACTIVE, NOW, null);
        when(groupMembershipRepository.findActiveByGroupIdAndUserIdForUpdate(groupId, adminId, GroupMembershipStatus.ACTIVE)).thenReturn(Optional.of(caller));

        GroupMembershipEntity target = new GroupMembershipEntity(UUID.randomUUID(), groupId, ownerId, GroupRole.OWNER, GroupMembershipStatus.ACTIVE, NOW, null);
        when(groupMembershipRepository.findActiveByGroupIdAndUserIdForUpdate(groupId, ownerId, GroupMembershipStatus.ACTIVE)).thenReturn(Optional.of(target));

        BusinessException ex = assertThrows(BusinessException.class, () -> banService.banMember(groupId, ownerId, adminId, null));
        assertEquals(ErrorCode.CANNOT_BAN_OWNER, ex.errorCode());
    }

    @Test
    void banMember_cannotBanSelf() {
        UUID groupId = UUID.randomUUID();
        UUID userId = UUID.randomUUID();

        BusinessException ex = assertThrows(BusinessException.class, () -> banService.banMember(groupId, userId, userId, null));
        assertEquals(ErrorCode.CANNOT_BAN_SELF, ex.errorCode());
    }

    @Test
    void unbanMember_happyPath() {
        UUID groupId = UUID.randomUUID();
        UUID callerId = UUID.randomUUID();
        UUID targetId = UUID.randomUUID();

        GroupEntity group = new GroupEntity(groupId, "Test", "Desc", null, GroupStatus.ACTIVE, callerId, NOW, NOW);
        when(groupRepository.findByIdForUpdate(groupId)).thenReturn(Optional.of(group));

        GroupMembershipEntity caller = new GroupMembershipEntity(UUID.randomUUID(), groupId, callerId, GroupRole.OWNER, GroupMembershipStatus.ACTIVE, NOW, null);
        when(groupMembershipRepository.findActiveByGroupIdAndUserIdForUpdate(groupId, callerId, GroupMembershipStatus.ACTIVE)).thenReturn(Optional.of(caller));

        GroupBanEntity ban = new GroupBanEntity(UUID.randomUUID(), groupId, targetId, callerId, "reason", NOW, null);
        when(groupBanRepository.findByGroupIdAndUserIdAndUnbannedAtIsNull(groupId, targetId)).thenReturn(Optional.of(ban));

        banService.unbanMember(groupId, targetId, callerId);

        assertFalse(ban.isActive());
        assertEquals(NOW, ban.getUnbannedAt());
        verify(groupActivityLogRepository).save(any());
    }
}
