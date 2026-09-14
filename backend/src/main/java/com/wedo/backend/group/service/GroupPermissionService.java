package com.wedo.backend.group.service;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.group.entity.GroupEntity;
import com.wedo.backend.group.entity.GroupMembershipEntity;
import com.wedo.backend.group.entity.GroupMembershipStatus;
import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.group.repository.GroupMembershipRepository;
import com.wedo.backend.group.repository.GroupRepository;
import com.wedo.backend.user.service.UserService;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
public class GroupPermissionService {

    private final UserService userService;
    private final GroupMembershipRepository groupMembershipRepository;
    private final GroupRepository groupRepository;

    public GroupPermissionService(
            UserService userService,
            GroupMembershipRepository groupMembershipRepository,
            GroupRepository groupRepository
    ) {
        this.userService = userService;
        this.groupMembershipRepository = groupMembershipRepository;
        this.groupRepository = groupRepository;
    }

    public ReadableGroupAccess requireReadableMembership(UUID groupId, UUID callerUserId) {
        userService.requireActiveUser(callerUserId);
        GroupMembershipEntity membership = groupMembershipRepository
                .findFirstByGroupIdAndUserIdAndStatus(groupId, callerUserId, GroupMembershipStatus.ACTIVE)
                .orElseThrow(() -> new BusinessException(ErrorCode.GROUP_NOT_FOUND));
        GroupEntity group = groupRepository.findById(groupId)
                .filter(candidate -> candidate.getStatus() != GroupStatus.DELETED)
                .orElseThrow(() -> new BusinessException(ErrorCode.GROUP_NOT_FOUND));
        return new ReadableGroupAccess(group, membership);
    }

    public ReadableGroupAccess requireMutableMembership(UUID groupId, UUID callerUserId) {
        ReadableGroupAccess access = requireReadableMembership(groupId, callerUserId);
        if (access.group().getStatus() == GroupStatus.ARCHIVED) {
            throw new BusinessException(ErrorCode.GROUP_ARCHIVED);
        }
        return access;
    }

    public ReadableGroupAccess requireAdminOrOwner(UUID groupId, UUID callerUserId) {
        ReadableGroupAccess access = requireMutableMembership(groupId, callerUserId);
        if (access.membership().getRole() != GroupRole.OWNER && access.membership().getRole() != GroupRole.ADMIN) {
            throw new BusinessException(ErrorCode.INSUFFICIENT_GROUP_PERMISSION);
        }
        return access;
    }

    public ReadableGroupAccess requireOwner(UUID groupId, UUID callerUserId) {
        ReadableGroupAccess access = requireMutableMembership(groupId, callerUserId);
        if (access.membership().getRole() != GroupRole.OWNER) {
            throw new BusinessException(ErrorCode.INSUFFICIENT_GROUP_PERMISSION);
        }
        return access;
    }
}
