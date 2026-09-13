package com.wedo.backend.group.service;

import com.wedo.backend.group.dto.CreateGroupRequest;
import com.wedo.backend.group.dto.GroupResponse;
import com.wedo.backend.group.entity.GroupActivityAction;
import com.wedo.backend.group.entity.GroupActivityLogEntity;
import com.wedo.backend.group.entity.GroupEntity;
import com.wedo.backend.group.entity.GroupMembershipEntity;
import com.wedo.backend.group.entity.GroupMembershipStatus;
import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.entity.GroupSettingsEntity;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.group.repository.GroupActivityLogRepository;
import com.wedo.backend.group.repository.GroupMembershipRepository;
import com.wedo.backend.group.repository.GroupRepository;
import com.wedo.backend.group.repository.GroupSettingsRepository;
import com.wedo.backend.user.service.UserService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.util.UUID;

@Service
public class GroupService {

    private final GroupRepository groupRepository;
    private final GroupSettingsRepository groupSettingsRepository;
    private final GroupMembershipRepository groupMembershipRepository;
    private final GroupActivityLogRepository groupActivityLogRepository;
    private final UserService userService;
    private final Clock clock;

    public GroupService(
            GroupRepository groupRepository,
            GroupSettingsRepository groupSettingsRepository,
            GroupMembershipRepository groupMembershipRepository,
            GroupActivityLogRepository groupActivityLogRepository,
            UserService userService,
            Clock clock
    ) {
        this.groupRepository = groupRepository;
        this.groupSettingsRepository = groupSettingsRepository;
        this.groupMembershipRepository = groupMembershipRepository;
        this.groupActivityLogRepository = groupActivityLogRepository;
        this.userService = userService;
        this.clock = clock;
    }

    @Transactional
    public GroupResponse createGroup(UUID creatorId, CreateGroupRequest request) {
        userService.requireActiveUser(creatorId);
        Instant now = clock.instant();
        UUID groupId = UUID.randomUUID();

        GroupEntity group = groupRepository.save(new GroupEntity(
                groupId,
                request.name(),
                request.description(),
                request.avatarStorageKey(),
                GroupStatus.ACTIVE,
                creatorId,
                now,
                now
        ));
        groupSettingsRepository.save(GroupSettingsEntity.createDefault(groupId, now));
        groupMembershipRepository.save(new GroupMembershipEntity(
                UUID.randomUUID(), groupId, creatorId, GroupRole.OWNER, GroupMembershipStatus.ACTIVE, now, null
        ));
        groupActivityLogRepository.save(new GroupActivityLogEntity(
                UUID.randomUUID(), groupId, creatorId, GroupActivityAction.GROUP_CREATED, now
        ));

        return GroupResponse.from(group);
    }
}
