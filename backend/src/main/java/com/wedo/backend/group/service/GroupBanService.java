package com.wedo.backend.group.service;

import com.wedo.backend.common.dto.PagedResponse;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.group.dto.GroupBanResponse;
import com.wedo.backend.group.entity.GroupActivityAction;
import com.wedo.backend.group.entity.GroupActivityLogEntity;
import com.wedo.backend.group.entity.GroupBanEntity;
import com.wedo.backend.group.entity.GroupEntity;
import com.wedo.backend.group.entity.GroupInvitationStatus;
import com.wedo.backend.group.entity.GroupJoinRequestStatus;
import com.wedo.backend.group.entity.GroupMembershipEntity;
import com.wedo.backend.group.entity.GroupMembershipStatus;
import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.group.event.GroupMembershipEndedEvent;
import com.wedo.backend.group.repository.GroupActivityLogRepository;
import com.wedo.backend.group.repository.GroupBanRepository;
import com.wedo.backend.group.repository.GroupInvitationRepository;
import com.wedo.backend.group.repository.GroupJoinRequestRepository;
import com.wedo.backend.group.repository.GroupMembershipRepository;
import com.wedo.backend.group.repository.GroupRepository;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.repository.UserRepository;
import com.wedo.backend.user.service.UserService;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.context.ApplicationEventPublisher;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
public class GroupBanService {

    private final GroupRepository groupRepository;
    private final GroupMembershipRepository groupMembershipRepository;
    private final GroupBanRepository groupBanRepository;
    private final GroupInvitationRepository groupInvitationRepository;
    private final GroupJoinRequestRepository groupJoinRequestRepository;
    private final GroupActivityLogRepository groupActivityLogRepository;
    private final UserRepository userRepository;
    private final UserService userService;
    private final GroupPermissionService groupPermissionService;
    private final Clock clock;
    private final ApplicationEventPublisher eventPublisher;

    public GroupBanService(
            GroupRepository groupRepository,
            GroupMembershipRepository groupMembershipRepository,
            GroupBanRepository groupBanRepository,
            GroupInvitationRepository groupInvitationRepository,
            GroupJoinRequestRepository groupJoinRequestRepository,
            GroupActivityLogRepository groupActivityLogRepository,
            UserRepository userRepository,
            UserService userService,
            GroupPermissionService groupPermissionService,
            Clock clock, ApplicationEventPublisher eventPublisher
    ) {
        this.groupRepository = groupRepository;
        this.groupMembershipRepository = groupMembershipRepository;
        this.groupBanRepository = groupBanRepository;
        this.groupInvitationRepository = groupInvitationRepository;
        this.groupJoinRequestRepository = groupJoinRequestRepository;
        this.groupActivityLogRepository = groupActivityLogRepository;
        this.userRepository = userRepository;
        this.userService = userService;
        this.groupPermissionService = groupPermissionService;
        this.clock = clock;
        this.eventPublisher = eventPublisher;
    }

    @Transactional
    public void banMember(UUID groupId, UUID targetUserId, UUID callerUserId, String reason) {
        if (callerUserId.equals(targetUserId)) {
            throw new BusinessException(ErrorCode.CANNOT_BAN_SELF);
        }

        userService.requireActiveUser(callerUserId);
        userService.requireActiveUser(targetUserId);

        GroupEntity group = groupRepository.findByIdForUpdate(groupId)
                .filter(g -> g.getStatus() != GroupStatus.DELETED)
                .orElseThrow(() -> new BusinessException(ErrorCode.GROUP_NOT_FOUND));

        if (group.getStatus() == GroupStatus.ARCHIVED) {
            throw new BusinessException(ErrorCode.GROUP_ARCHIVED);
        }

        GroupMembershipEntity caller = groupMembershipRepository
                .findActiveByGroupIdAndUserIdForUpdate(groupId, callerUserId, GroupMembershipStatus.ACTIVE)
                .orElseThrow(() -> new BusinessException(ErrorCode.INSUFFICIENT_GROUP_PERMISSION));

        if (caller.getRole() != GroupRole.OWNER && caller.getRole() != GroupRole.ADMIN) {
            throw new BusinessException(ErrorCode.INSUFFICIENT_GROUP_PERMISSION);
        }

        if (groupBanRepository.existsByGroupIdAndUserIdAndUnbannedAtIsNull(groupId, targetUserId)) {
            throw new BusinessException(ErrorCode.USER_ALREADY_BANNED);
        }

        Instant now = clock.instant();

        Optional<GroupMembershipEntity> targetOpt = groupMembershipRepository
                .findActiveByGroupIdAndUserIdForUpdate(groupId, targetUserId, GroupMembershipStatus.ACTIVE);

        if (targetOpt.isPresent()) {
            GroupMembershipEntity target = targetOpt.get();
            if (target.getRole() == GroupRole.OWNER) {
                throw new BusinessException(ErrorCode.CANNOT_BAN_OWNER);
            }
            if (caller.getRole() == GroupRole.ADMIN && target.getRole() != GroupRole.MEMBER) {
                throw new BusinessException(ErrorCode.CANNOT_BAN_ADMIN);
            }
            target.endAsBanned(now);
            eventPublisher.publishEvent(new GroupMembershipEndedEvent(target.getId(), groupId, targetUserId, target.getRole(), GroupMembershipStatus.BANNED, now));
        }

        groupBanRepository.save(new GroupBanEntity(
                UUID.randomUUID(),
                groupId,
                targetUserId,
                callerUserId,
                reason,
                now,
                null
        ));

        // Cancel pending invitations
        groupInvitationRepository.findByGroupIdAndInviteeId(groupId, targetUserId).stream()
                .filter(i -> i.getStatus() == GroupInvitationStatus.PENDING)
                .forEach(i -> i.cancel(now));

        // Cancel pending join requests
        groupJoinRequestRepository.findByGroupIdAndUserId(groupId, targetUserId).stream()
                .filter(r -> r.getStatus() == GroupJoinRequestStatus.PENDING)
                .forEach(r -> r.cancel(now));

        // Log activity
        groupActivityLogRepository.save(new GroupActivityLogEntity(
                UUID.randomUUID(),
                groupId,
                callerUserId,
                GroupActivityAction.GROUP_MEMBER_BANNED,
                targetUserId,
                now
        ));
    }

    @Transactional(readOnly = true)
    public PagedResponse<GroupBanResponse> getBans(UUID groupId, UUID callerUserId, int page, int size) {
        groupPermissionService.requireAdminOrOwner(groupId, callerUserId);
        Page<GroupBanEntity> bans = groupBanRepository.findByGroupIdAndUnbannedAtIsNullOrderByCreatedAtDesc(
                groupId,
                PageRequest.of(page, size)
        );

        List<GroupBanResponse> responses = bans.getContent().stream().map(ban -> {
            UserEntity user = userRepository.findById(ban.getUserId()).orElse(null);
            String username = user != null ? user.getUsername() : "";
            String displayName = user != null ? user.getDisplayName() : "";
            String avatarKey = user != null ? user.getAvatarStorageKey() : null;
            return GroupBanResponse.of(ban, username, displayName, avatarKey);
        }).toList();

        return PagedResponse.from(bans, responses);
    }

    @Transactional
    public void unbanMember(UUID groupId, UUID targetUserId, UUID callerUserId) {
        userService.requireActiveUser(callerUserId);

        GroupEntity group = groupRepository.findByIdForUpdate(groupId)
                .filter(g -> g.getStatus() != GroupStatus.DELETED)
                .orElseThrow(() -> new BusinessException(ErrorCode.GROUP_NOT_FOUND));

        if (group.getStatus() == GroupStatus.ARCHIVED) {
            throw new BusinessException(ErrorCode.GROUP_ARCHIVED);
        }

        GroupMembershipEntity caller = groupMembershipRepository
                .findActiveByGroupIdAndUserIdForUpdate(groupId, callerUserId, GroupMembershipStatus.ACTIVE)
                .orElseThrow(() -> new BusinessException(ErrorCode.INSUFFICIENT_GROUP_PERMISSION));

        if (caller.getRole() != GroupRole.OWNER && caller.getRole() != GroupRole.ADMIN) {
            throw new BusinessException(ErrorCode.INSUFFICIENT_GROUP_PERMISSION);
        }

        GroupBanEntity ban = groupBanRepository.findByGroupIdAndUserIdAndUnbannedAtIsNull(groupId, targetUserId)
                .orElseThrow(() -> new BusinessException(ErrorCode.USER_NOT_BANNED));

        Instant now = clock.instant();
        ban.unban(now);

        groupActivityLogRepository.save(new GroupActivityLogEntity(
                UUID.randomUUID(),
                groupId,
                callerUserId,
                GroupActivityAction.GROUP_MEMBER_UNBANNED,
                targetUserId,
                now
        ));
    }
}
