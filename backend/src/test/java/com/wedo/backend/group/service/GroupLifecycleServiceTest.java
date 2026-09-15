package com.wedo.backend.group.service;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.group.entity.GroupActivityAction;
import com.wedo.backend.group.entity.GroupActivityLogEntity;
import com.wedo.backend.group.entity.GroupEntity;
import com.wedo.backend.group.entity.GroupMembershipEntity;
import com.wedo.backend.group.entity.GroupMembershipStatus;
import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.group.repository.GroupActivityLogRepository;
import com.wedo.backend.group.repository.GroupRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class GroupLifecycleServiceTest {

    private static final Instant NOW = Instant.parse("2026-09-15T12:00:00Z");
    private final Clock clock = Clock.fixed(NOW, ZoneOffset.UTC);

    @Mock private GroupRepository groupRepository;
    @Mock private GroupActivityLogRepository groupActivityLogRepository;
    @Mock private GroupPermissionService groupPermissionService;

    private GroupLifecycleService lifecycleService;

    @BeforeEach
    void setUp() {
        lifecycleService = new GroupLifecycleService(
                groupRepository,
                groupActivityLogRepository,
                groupPermissionService,
                clock
        );
    }

    @Test
    void archiveGroup_happyPath() {
        UUID groupId = UUID.randomUUID();
        UUID ownerId = UUID.randomUUID();

        GroupEntity group = new GroupEntity(groupId, "Active Group", "Desc", null, GroupStatus.ACTIVE, ownerId, NOW, NOW);
        GroupMembershipEntity membership = new GroupMembershipEntity(UUID.randomUUID(), groupId, ownerId, GroupRole.OWNER, GroupMembershipStatus.ACTIVE, NOW, null);

        when(groupPermissionService.requireOwner(groupId, ownerId)).thenReturn(new ReadableGroupAccess(group, membership));

        lifecycleService.archiveGroup(groupId, ownerId);

        assertEquals(GroupStatus.ARCHIVED, group.getStatus());
        assertEquals(NOW, group.getUpdatedAt());

        ArgumentCaptor<GroupActivityLogEntity> logCaptor = ArgumentCaptor.forClass(GroupActivityLogEntity.class);
        verify(groupActivityLogRepository).save(logCaptor.capture());
        assertEquals(GroupActivityAction.GROUP_ARCHIVED, logCaptor.getValue().getAction());
    }

    @Test
    void restoreGroup_happyPath() {
        UUID groupId = UUID.randomUUID();
        UUID ownerId = UUID.randomUUID();

        GroupEntity group = new GroupEntity(groupId, "Archived Group", "Desc", null, GroupStatus.ARCHIVED, ownerId, NOW, NOW);
        GroupMembershipEntity membership = new GroupMembershipEntity(UUID.randomUUID(), groupId, ownerId, GroupRole.OWNER, GroupMembershipStatus.ACTIVE, NOW, null);

        when(groupPermissionService.requireOwnerForRestore(groupId, ownerId)).thenReturn(new ReadableGroupAccess(group, membership));

        lifecycleService.restoreGroup(groupId, ownerId);

        assertEquals(GroupStatus.ACTIVE, group.getStatus());
        assertEquals(NOW, group.getUpdatedAt());

        ArgumentCaptor<GroupActivityLogEntity> logCaptor = ArgumentCaptor.forClass(GroupActivityLogEntity.class);
        verify(groupActivityLogRepository).save(logCaptor.capture());
        assertEquals(GroupActivityAction.GROUP_RESTORED, logCaptor.getValue().getAction());
    }

    @Test
    void deleteGroup_happyPath() {
        UUID groupId = UUID.randomUUID();
        UUID ownerId = UUID.randomUUID();

        GroupEntity group = new GroupEntity(groupId, "Active Group", "Desc", null, GroupStatus.ACTIVE, ownerId, NOW, NOW);
        GroupMembershipEntity membership = new GroupMembershipEntity(UUID.randomUUID(), groupId, ownerId, GroupRole.OWNER, GroupMembershipStatus.ACTIVE, NOW, null);

        when(groupPermissionService.requireOwnerForRestore(groupId, ownerId)).thenReturn(new ReadableGroupAccess(group, membership));

        lifecycleService.deleteGroup(groupId, ownerId);

        assertEquals(GroupStatus.DELETED, group.getStatus());
        assertEquals(NOW, group.getUpdatedAt());

        ArgumentCaptor<GroupActivityLogEntity> logCaptor = ArgumentCaptor.forClass(GroupActivityLogEntity.class);
        verify(groupActivityLogRepository).save(logCaptor.capture());
        assertEquals(GroupActivityAction.GROUP_DELETED, logCaptor.getValue().getAction());
    }

    @Test
    void deleteGroup_alreadyDeleted_throwsNotFound() {
        UUID groupId = UUID.randomUUID();
        UUID ownerId = UUID.randomUUID();

        GroupEntity group = new GroupEntity(groupId, "Deleted Group", "Desc", null, GroupStatus.DELETED, ownerId, NOW, NOW);
        GroupMembershipEntity membership = new GroupMembershipEntity(UUID.randomUUID(), groupId, ownerId, GroupRole.OWNER, GroupMembershipStatus.ACTIVE, NOW, null);

        when(groupPermissionService.requireOwnerForRestore(groupId, ownerId)).thenReturn(new ReadableGroupAccess(group, membership));

        BusinessException ex = assertThrows(BusinessException.class, () -> lifecycleService.deleteGroup(groupId, ownerId));
        assertEquals(ErrorCode.GROUP_NOT_FOUND, ex.errorCode());
    }
}
