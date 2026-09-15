package com.wedo.backend.group.service;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.group.entity.GroupActivityAction;
import com.wedo.backend.group.entity.GroupActivityLogEntity;
import com.wedo.backend.group.entity.GroupEntity;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.group.repository.GroupActivityLogRepository;
import com.wedo.backend.group.repository.GroupRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.util.UUID;

@Service
public class GroupLifecycleService {

    private final GroupRepository groupRepository;
    private final GroupActivityLogRepository groupActivityLogRepository;
    private final GroupPermissionService groupPermissionService;
    private final Clock clock;

    public GroupLifecycleService(
            GroupRepository groupRepository,
            GroupActivityLogRepository groupActivityLogRepository,
            GroupPermissionService groupPermissionService,
            Clock clock
    ) {
        this.groupRepository = groupRepository;
        this.groupActivityLogRepository = groupActivityLogRepository;
        this.groupPermissionService = groupPermissionService;
        this.clock = clock;
    }

    @Transactional
    public void archiveGroup(UUID groupId, UUID callerUserId) {
        ReadableGroupAccess access = groupPermissionService.requireOwner(groupId, callerUserId);
        GroupEntity group = access.group();

        if (group.getStatus() != GroupStatus.ACTIVE) {
            throw new BusinessException(ErrorCode.GROUP_ARCHIVED);
        }

        Instant now = clock.instant();
        group.archive(now);

        groupActivityLogRepository.save(new GroupActivityLogEntity(
                UUID.randomUUID(),
                groupId,
                callerUserId,
                GroupActivityAction.GROUP_ARCHIVED,
                now
        ));
    }

    @Transactional
    public void restoreGroup(UUID groupId, UUID callerUserId) {
        ReadableGroupAccess access = groupPermissionService.requireOwnerForRestore(groupId, callerUserId);
        GroupEntity group = access.group();

        if (group.getStatus() != GroupStatus.ARCHIVED) {
            throw new BusinessException(ErrorCode.CONFLICT);
        }

        Instant now = clock.instant();
        group.restore(now);

        groupActivityLogRepository.save(new GroupActivityLogEntity(
                UUID.randomUUID(),
                groupId,
                callerUserId,
                GroupActivityAction.GROUP_RESTORED,
                now
        ));
    }

    @Transactional
    public void deleteGroup(UUID groupId, UUID callerUserId) {
        ReadableGroupAccess access = groupPermissionService.requireOwnerForRestore(groupId, callerUserId);
        GroupEntity group = access.group();

        if (group.getStatus() == GroupStatus.DELETED) {
            throw new BusinessException(ErrorCode.GROUP_NOT_FOUND);
        }

        Instant now = clock.instant();
        group.delete(now);

        groupActivityLogRepository.save(new GroupActivityLogEntity(
                UUID.randomUUID(),
                groupId,
                callerUserId,
                GroupActivityAction.GROUP_DELETED,
                now
        ));
    }
}
