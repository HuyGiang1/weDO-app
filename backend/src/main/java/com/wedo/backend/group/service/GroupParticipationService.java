package com.wedo.backend.group.service;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.group.entity.GroupEntity;
import com.wedo.backend.group.entity.GroupMembershipEntity;
import com.wedo.backend.group.entity.GroupMembershipStatus;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.group.repository.GroupBanRepository;
import com.wedo.backend.group.repository.GroupMembershipRepository;
import com.wedo.backend.group.repository.GroupRepository;
import com.wedo.backend.user.service.UserService;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class GroupParticipationService {
    private final UserService userService;
    private final GroupRepository groups;
    private final GroupMembershipRepository memberships;
    private final GroupBanRepository bans;

    public GroupParticipationService(UserService userService, GroupRepository groups, GroupMembershipRepository memberships, GroupBanRepository bans) {
        this.userService = userService; this.groups = groups; this.memberships = memberships; this.bans = bans;
    }

    @Transactional
    public GroupParticipationAccess lockActiveUnbannedMutableParticipation(UUID groupId, UUID userId) {
        userService.requireActiveUser(userId);
        GroupEntity group = groups.findByIdForUpdate(groupId).filter(g -> g.getStatus() != GroupStatus.DELETED)
                .orElseThrow(() -> new BusinessException(ErrorCode.GROUP_NOT_FOUND));
        if (group.getStatus() == GroupStatus.ARCHIVED) throw new BusinessException(ErrorCode.GROUP_ARCHIVED);
        GroupMembershipEntity membership = memberships.findActiveByGroupIdAndUserIdForUpdate(groupId, userId, GroupMembershipStatus.ACTIVE)
                .orElseThrow(() -> new BusinessException(ErrorCode.GROUP_NOT_FOUND));
        if (bans.existsByGroupIdAndUserIdAndUnbannedAtIsNull(groupId, userId)) throw new BusinessException(ErrorCode.USER_BANNED_FROM_GROUP);
        return new GroupParticipationAccess(group, membership);
    }
}
