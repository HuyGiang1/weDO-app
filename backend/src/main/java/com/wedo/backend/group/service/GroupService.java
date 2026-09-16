package com.wedo.backend.group.service;

import com.wedo.backend.group.dto.CreateGroupRequest;
import com.wedo.backend.group.dto.GroupResponse;
import com.wedo.backend.group.dto.GroupDetailResponse;
import com.wedo.backend.group.dto.GroupMemberResponse;
import com.wedo.backend.group.dto.GroupSummaryResponse;
import com.wedo.backend.group.dto.GroupSettingsResponse;
import com.wedo.backend.group.dto.GroupActivityLogResponse;
import com.wedo.backend.group.dto.UpdateGroupRequest;
import com.wedo.backend.group.dto.UpdateGroupSettingsRequest;
import com.wedo.backend.group.entity.GroupActivityAction;
import com.wedo.backend.group.entity.GroupActivityLogEntity;
import com.wedo.backend.group.entity.GroupEntity;
import com.wedo.backend.group.entity.GroupMembershipEntity;
import com.wedo.backend.group.entity.GroupMembershipStatus;
import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.entity.GroupSettingsEntity;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.group.event.GroupMembershipEndedEvent;
import com.wedo.backend.group.repository.GroupActivityLogRepository;
import com.wedo.backend.group.repository.GroupMembershipRepository;
import com.wedo.backend.group.repository.GroupRepository;
import com.wedo.backend.group.repository.GroupSettingsRepository;
import com.wedo.backend.common.dto.PagedResponse;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import com.wedo.backend.user.service.UserService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.context.ApplicationEventPublisher;

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
    private final GroupPermissionService groupPermissionService;
    private final Clock clock;
    private final ApplicationEventPublisher eventPublisher;

    public GroupService(
            GroupRepository groupRepository,
            GroupSettingsRepository groupSettingsRepository,
            GroupMembershipRepository groupMembershipRepository,
            GroupActivityLogRepository groupActivityLogRepository,
            UserService userService,
            GroupPermissionService groupPermissionService,
            Clock clock, ApplicationEventPublisher eventPublisher
    ) {
        this.groupRepository = groupRepository;
        this.groupSettingsRepository = groupSettingsRepository;
        this.groupMembershipRepository = groupMembershipRepository;
        this.groupActivityLogRepository = groupActivityLogRepository;
        this.userService = userService;
        this.groupPermissionService = groupPermissionService;
        this.clock = clock;
        this.eventPublisher = eventPublisher;
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

    @Transactional(readOnly = true)
    public PagedResponse<GroupSummaryResponse> getGroups(UUID callerUserId, int page, int size, GroupStatus status) {
        userService.requireActiveUser(callerUserId);
        Page<GroupSummaryResponse> summaries = groupMembershipRepository.findGroupSummariesByActiveMember(
                        callerUserId, status.name(), PageRequest.of(page, size)
                )
                .map(GroupSummaryResponse::from);
        return PagedResponse.from(summaries, summaries.getContent());
    }

    @Transactional(readOnly = true)
    public GroupDetailResponse getGroup(UUID groupId, UUID callerUserId) {
        ReadableGroupAccess access = groupPermissionService.requireReadableMembership(groupId, callerUserId);
        UUID ownerUserId = groupMembershipRepository
                .findFirstByGroupIdAndRoleAndStatus(groupId, GroupRole.OWNER, GroupMembershipStatus.ACTIVE)
                .map(GroupMembershipEntity::getUserId)
                .orElseThrow(() -> new BusinessException(ErrorCode.GROUP_NOT_FOUND));
        return GroupDetailResponse.of(access.group(), ownerUserId, access.membership().getRole());
    }

    @Transactional(readOnly = true)
    public java.util.List<GroupMemberResponse> getMembers(UUID groupId, UUID callerUserId) {
        groupPermissionService.requireReadableMembership(groupId, callerUserId);
        return groupMembershipRepository.findActiveMemberResponsesByGroupId(groupId).stream()
                .map(GroupMemberResponse::from)
                .toList();
    }

    @Transactional(readOnly = true)
    public PagedResponse<GroupActivityLogResponse> getActivityLogs(UUID groupId, UUID callerUserId, int page, int size) {
        groupPermissionService.requireReadableMembership(groupId, callerUserId);
        Page<GroupActivityLogEntity> logs = groupActivityLogRepository.findByGroupId(groupId,
                PageRequest.of(page, size, Sort.by(Sort.Order.desc("createdAt"), Sort.Order.desc("id"))));
        return PagedResponse.from(logs, logs.getContent().stream().map(GroupActivityLogResponse::from).toList());
    }

    @Transactional(readOnly = true)
    public GroupMemberResponse getMember(UUID groupId, UUID targetUserId, UUID callerUserId) {
        groupPermissionService.requireReadableMembership(groupId, callerUserId);
        return groupMembershipRepository.findActiveMemberResponseByGroupIdAndUserId(groupId, targetUserId)
                .map(GroupMemberResponse::from)
                .orElseThrow(() -> new BusinessException(ErrorCode.GROUP_MEMBER_NOT_FOUND));
    }

    @Transactional
    public GroupDetailResponse updateGroup(UUID groupId, UUID callerUserId, UpdateGroupRequest request) {
        ReadableGroupAccess access = groupPermissionService.requireAdminOrOwner(groupId, callerUserId);
        GroupEntity group = access.group();
        String name = request.name() == null ? group.getName() : requireNonBlankName(request.name());
        String description = request.description() == null ? group.getDescription() : clearIfBlank(request.description());
        String avatarStorageKey = request.avatarStorageKey() == null ? group.getAvatarStorageKey() : clearIfBlank(request.avatarStorageKey());
        group.updateMetadata(name, description, avatarStorageKey, clock.instant());
        groupActivityLogRepository.save(new GroupActivityLogEntity(UUID.randomUUID(), groupId, callerUserId, GroupActivityAction.GROUP_UPDATED, clock.instant()));
        return detailResponse(group, access.membership().getRole());
    }

    @Transactional(readOnly = true)
    public GroupSettingsResponse getSettings(UUID groupId, UUID callerUserId) {
        groupPermissionService.requireReadableMembership(groupId, callerUserId);
        return GroupSettingsResponse.from(requireSettings(groupId));
    }

    @Transactional
    public GroupSettingsResponse updateSettings(UUID groupId, UUID callerUserId, UpdateGroupSettingsRequest request) {
        groupPermissionService.requireOwner(groupId, callerUserId);
        GroupSettingsEntity settings = requireSettings(groupId);
        settings.update(
                request.joinPolicy() == null ? settings.getJoinPolicy() : request.joinPolicy(),
                request.memberModifyInfoAllowed() == null ? settings.isMemberModifyInfoAllowed() : request.memberModifyInfoAllowed(),
                request.memberCreateActivityAllowed() == null ? settings.isMemberCreateActivityAllowed() : request.memberCreateActivityAllowed(),
                request.memberPinMessageAllowed() == null ? settings.isMemberPinMessageAllowed() : request.memberPinMessageAllowed(),
                request.chatHistoryPolicy() == null ? settings.getChatHistoryPolicy() : request.chatHistoryPolicy(),
                clock.instant()
        );
        groupActivityLogRepository.save(new GroupActivityLogEntity(UUID.randomUUID(), groupId, callerUserId, GroupActivityAction.GROUP_SETTINGS_UPDATED, clock.instant()));
        return GroupSettingsResponse.from(settings);
    }

    private GroupDetailResponse detailResponse(GroupEntity group, GroupRole callerRole) {
        UUID ownerUserId = groupMembershipRepository
                .findFirstByGroupIdAndRoleAndStatus(group.getId(), GroupRole.OWNER, GroupMembershipStatus.ACTIVE)
                .map(GroupMembershipEntity::getUserId)
                .orElseThrow(() -> new BusinessException(ErrorCode.GROUP_NOT_FOUND));
        return GroupDetailResponse.of(group, ownerUserId, callerRole);
    }

    private GroupSettingsEntity requireSettings(UUID groupId) {
        return groupSettingsRepository.findById(groupId)
                .orElseThrow(() -> new IllegalStateException("Group is missing settings"));
    }

    private String requireNonBlankName(String value) {
        if (value.isBlank()) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
        return value;
    }

    private String clearIfBlank(String value) {
        return value.isBlank() ? null : value;
    }

    @Transactional
    public GroupMemberResponse promoteAdmin(UUID groupId, UUID targetUserId, UUID callerUserId) {
        GroupMembershipEntity caller = requireLockedMutableCaller(groupId, callerUserId);
        requireOwner(caller);
        GroupMembershipEntity target = requireLockedActiveTarget(groupId, targetUserId);
        if (target.getRole() != GroupRole.MEMBER) throw new BusinessException(ErrorCode.INVALID_GROUP_ROLE_TRANSITION);
        target.promoteToAdmin();
        groupActivityLogRepository.save(new GroupActivityLogEntity(UUID.randomUUID(), groupId, callerUserId, GroupActivityAction.GROUP_ADMIN_PROMOTED, targetUserId, clock.instant()));
        return activeMemberResponse(groupId, targetUserId);
    }

    @Transactional
    public GroupMemberResponse demoteAdmin(UUID groupId, UUID targetUserId, UUID callerUserId) {
        GroupMembershipEntity caller = requireLockedMutableCaller(groupId, callerUserId);
        requireOwner(caller);
        GroupMembershipEntity target = requireLockedActiveTarget(groupId, targetUserId);
        if (target.getRole() != GroupRole.ADMIN) throw new BusinessException(ErrorCode.INVALID_GROUP_ROLE_TRANSITION);
        target.demoteToMember();
        groupActivityLogRepository.save(new GroupActivityLogEntity(UUID.randomUUID(), groupId, callerUserId, GroupActivityAction.GROUP_ADMIN_DEMOTED, targetUserId, clock.instant()));
        return activeMemberResponse(groupId, targetUserId);
    }

    @Transactional
    public void kick(UUID groupId, UUID targetUserId, UUID callerUserId) {
        GroupMembershipEntity caller = requireLockedMutableCaller(groupId, callerUserId);
        GroupMembershipEntity target = requireLockedActiveTarget(groupId, targetUserId);
        boolean allowed = caller.getRole() == GroupRole.OWNER && target.getRole() != GroupRole.OWNER
                || caller.getRole() == GroupRole.ADMIN && target.getRole() == GroupRole.MEMBER;
        if (!allowed) throw new BusinessException(ErrorCode.INSUFFICIENT_GROUP_PERMISSION);
        Instant now = clock.instant();
        target.endAsKicked(now);
        eventPublisher.publishEvent(new GroupMembershipEndedEvent(target.getId(), groupId, targetUserId, target.getRole(), GroupMembershipStatus.KICKED, now));
        groupActivityLogRepository.save(new GroupActivityLogEntity(UUID.randomUUID(), groupId, callerUserId, GroupActivityAction.GROUP_MEMBER_KICKED, targetUserId, now));
    }

    @Transactional
    public void leave(UUID groupId, UUID callerUserId) {
        GroupMembershipEntity caller = requireLockedMutableCaller(groupId, callerUserId);
        if (caller.getRole() == GroupRole.OWNER) throw new BusinessException(ErrorCode.TRANSFER_OWNERSHIP_REQUIRED);
        Instant now = clock.instant();
        caller.endAsLeft(now);
        eventPublisher.publishEvent(new GroupMembershipEndedEvent(caller.getId(), groupId, callerUserId, caller.getRole(), GroupMembershipStatus.LEFT, now));
        groupActivityLogRepository.save(new GroupActivityLogEntity(UUID.randomUUID(), groupId, callerUserId, GroupActivityAction.GROUP_MEMBER_LEFT, callerUserId, now));
    }

    @Transactional
    public GroupDetailResponse transferOwnership(UUID groupId, UUID targetUserId, UUID callerUserId) {
        GroupMembershipEntity caller = requireLockedMutableCaller(groupId, callerUserId);
        requireOwner(caller);
        GroupMembershipEntity target = requireLockedActiveTarget(groupId, targetUserId);
        if (targetUserId.equals(callerUserId) || (target.getRole() != GroupRole.MEMBER && target.getRole() != GroupRole.ADMIN)) throw new BusinessException(ErrorCode.INVALID_OWNERSHIP_TARGET);
        caller.transferOwnerToAdmin();
        groupMembershipRepository.flush();
        target.transferToOwner();
        Instant now = clock.instant();
        groupActivityLogRepository.save(new GroupActivityLogEntity(UUID.randomUUID(), groupId, callerUserId, GroupActivityAction.GROUP_OWNERSHIP_TRANSFERRED, targetUserId, now));
        GroupEntity group = groupRepository.findById(groupId).orElseThrow(() -> new BusinessException(ErrorCode.GROUP_NOT_FOUND));
        return detailResponse(group, GroupRole.ADMIN);
    }

    private GroupMembershipEntity requireLockedMutableCaller(UUID groupId, UUID callerUserId) {
        userService.requireActiveUser(callerUserId);
        GroupEntity group = groupRepository.findByIdForUpdate(groupId)
                .filter(candidate -> candidate.getStatus() != GroupStatus.DELETED)
                .orElseThrow(() -> new BusinessException(ErrorCode.GROUP_NOT_FOUND));
        if (group.getStatus() == GroupStatus.ARCHIVED) throw new BusinessException(ErrorCode.GROUP_ARCHIVED);
        return groupMembershipRepository.findActiveByGroupIdAndUserIdForUpdate(groupId, callerUserId, GroupMembershipStatus.ACTIVE)
                .orElseThrow(() -> new BusinessException(ErrorCode.GROUP_NOT_FOUND));
    }

    private GroupMembershipEntity requireLockedActiveTarget(UUID groupId, UUID targetUserId) {
        return groupMembershipRepository.findActiveByGroupIdAndUserIdForUpdate(groupId, targetUserId, GroupMembershipStatus.ACTIVE)
                .orElseThrow(() -> new BusinessException(ErrorCode.GROUP_MEMBER_NOT_FOUND));
    }

    private void requireOwner(GroupMembershipEntity membership) {
        if (membership.getRole() != GroupRole.OWNER) throw new BusinessException(ErrorCode.INSUFFICIENT_GROUP_PERMISSION);
    }

    private GroupMemberResponse activeMemberResponse(UUID groupId, UUID userId) {
        return groupMembershipRepository.findActiveMemberResponseByGroupIdAndUserId(groupId, userId)
                .map(GroupMemberResponse::from)
                .orElseThrow(() -> new BusinessException(ErrorCode.GROUP_MEMBER_NOT_FOUND));
    }
}
