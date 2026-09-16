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
import com.wedo.backend.group.entity.GroupActivityAction;
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
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.Clock;
import java.time.Instant;
import java.util.Base64;
import java.util.List;
import java.util.Objects;
import java.util.UUID;

@Service
public class GroupAdmissionService {

    private static final int CAPACITY_LIMIT = 100;
    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    private final GroupRepository groupRepository;
    private final GroupSettingsRepository groupSettingsRepository;
    private final GroupMembershipRepository groupMembershipRepository;
    private final GroupActivityLogRepository groupActivityLogRepository;
    private final GroupInvitationRepository groupInvitationRepository;
    private final GroupInviteLinkRepository groupInviteLinkRepository;
    private final GroupJoinRequestRepository groupJoinRequestRepository;
    private final GroupBanRepository groupBanRepository;
    private final UserRepository userRepository;
    private final UserService userService;
    private final GroupPermissionService groupPermissionService;
    private final Clock clock;

    public GroupAdmissionService(
            GroupRepository groupRepository,
            GroupSettingsRepository groupSettingsRepository,
            GroupMembershipRepository groupMembershipRepository,
            GroupActivityLogRepository groupActivityLogRepository,
            GroupInvitationRepository groupInvitationRepository,
            GroupInviteLinkRepository groupInviteLinkRepository,
            GroupJoinRequestRepository groupJoinRequestRepository,
            GroupBanRepository groupBanRepository,
            UserRepository userRepository,
            UserService userService,
            GroupPermissionService groupPermissionService,
            Clock clock
    ) {
        this.groupRepository = groupRepository;
        this.groupSettingsRepository = groupSettingsRepository;
        this.groupMembershipRepository = groupMembershipRepository;
        this.groupActivityLogRepository = groupActivityLogRepository;
        this.groupInvitationRepository = groupInvitationRepository;
        this.groupInviteLinkRepository = groupInviteLinkRepository;
        this.groupJoinRequestRepository = groupJoinRequestRepository;
        this.groupBanRepository = groupBanRepository;
        this.userRepository = userRepository;
        this.userService = userService;
        this.groupPermissionService = groupPermissionService;
        this.clock = clock;
    }

    // =========================================================================
    // Concurrency-Safe Admission Helper (Capacity = 100)
    // =========================================================================
    @Transactional
    public GroupMembershipEntity admitMemberUnderGroupLock(UUID groupId, UUID userId) {
        Instant now = clock.instant();

        // 1. SELECT group FOR UPDATE
        GroupEntity group = groupRepository.findByIdForUpdate(groupId)
                .filter(g -> g.getStatus() != GroupStatus.DELETED)
                .orElseThrow(() -> new BusinessException(ErrorCode.GROUP_NOT_FOUND));

        if (group.getStatus() == GroupStatus.ARCHIVED) {
            throw new BusinessException(ErrorCode.GROUP_ARCHIVED);
        }

        // 2. Validate user eligibility
        userService.requireActiveUser(userId);

        if (groupBanRepository.existsByGroupIdAndUserIdAndUnbannedAtIsNull(groupId, userId)) {
            throw new BusinessException(ErrorCode.USER_BANNED_FROM_GROUP);
        }

        if (groupMembershipRepository.findFirstByGroupIdAndUserIdAndStatus(groupId, userId, GroupMembershipStatus.ACTIVE).isPresent()) {
            throw new BusinessException(ErrorCode.ALREADY_GROUP_MEMBER);
        }

        // 3. Evaluate capacity under row lock
        long activeCount = groupMembershipRepository.countByGroupIdAndStatus(groupId, GroupMembershipStatus.ACTIVE);
        if (activeCount >= CAPACITY_LIMIT) {
            throw new BusinessException(ErrorCode.GROUP_MEMBER_LIMIT_REACHED);
        }

        // 4. Create ACTIVE membership
        GroupMembershipEntity membership = groupMembershipRepository.save(new GroupMembershipEntity(
                UUID.randomUUID(),
                groupId,
                userId,
                GroupRole.MEMBER,
                GroupMembershipStatus.ACTIVE,
                now,
                null
        ));

        // 5. Activity log
        groupActivityLogRepository.save(new GroupActivityLogEntity(
                UUID.randomUUID(),
                groupId,
                userId,
                GroupActivityAction.GROUP_MEMBER_JOINED,
                userId,
                now
        ));

        return membership;
    }

    // =========================================================================
    // Direct Invitations
    // =========================================================================
    @Transactional
    public GroupInvitationResponse createInvitation(UUID groupId, UUID callerUserId, CreateInvitationRequest request) {
        ReadableGroupAccess access = groupPermissionService.requireAdminOrOwner(groupId, callerUserId);
        UUID inviteeId = request.inviteeUserId();

        if (callerUserId.equals(inviteeId)) {
            throw new BusinessException(ErrorCode.CANNOT_INVITE_SELF);
        }

        userService.requireActiveUser(inviteeId);

        if (groupBanRepository.existsByGroupIdAndUserIdAndUnbannedAtIsNull(groupId, inviteeId)) {
            throw new BusinessException(ErrorCode.USER_BANNED_FROM_GROUP);
        }

        if (groupMembershipRepository.findFirstByGroupIdAndUserIdAndStatus(groupId, inviteeId, GroupMembershipStatus.ACTIVE).isPresent()) {
            throw new BusinessException(ErrorCode.ALREADY_GROUP_MEMBER);
        }

        if (groupInvitationRepository.existsByGroupIdAndInviteeIdAndStatus(groupId, inviteeId, GroupInvitationStatus.PENDING)) {
            throw new BusinessException(ErrorCode.INVITATION_ALREADY_RESOLVED);
        }

        Instant now = clock.instant();
        GroupInvitationEntity invitation = groupInvitationRepository.save(new GroupInvitationEntity(
                UUID.randomUUID(),
                groupId,
                callerUserId,
                inviteeId,
                GroupInvitationStatus.PENDING,
                now,
                null
        ));

        UserEntity inviter = userRepository.findById(callerUserId).orElse(null);
        String inviterName = inviter != null ? inviter.getDisplayName() : null;

        return GroupInvitationResponse.of(invitation, access.group().getName(), access.group().getAvatarStorageKey(), inviterName);
    }

    @Transactional(readOnly = true)
    public PagedResponse<GroupInvitationResponse> getMyInvitations(UUID userId, int page, int size, GroupInvitationStatus status) {
        userService.requireActiveUser(userId);
        Page<GroupInvitationEntity> invitations = groupInvitationRepository.findByInviteeIdAndStatus(
                userId,
                status,
                PageRequest.of(page, size, Sort.by("createdAt").descending())
        );

        List<GroupInvitationResponse> responses = invitations.getContent().stream().map(invitation -> {
            GroupEntity group = groupRepository.findById(invitation.getGroupId()).orElse(null);
            String groupName = group != null ? group.getName() : "";
            String avatarKey = group != null ? group.getAvatarStorageKey() : null;
            String inviterName = null;
            if (invitation.getInviterId() != null) {
                inviterName = userRepository.findById(invitation.getInviterId())
                        .map(UserEntity::getDisplayName)
                        .orElse(null);
            }
            return GroupInvitationResponse.of(invitation, groupName, avatarKey, inviterName);
        }).toList();

        return PagedResponse.from(invitations, responses);
    }

    @Transactional
    public void acceptInvitation(UUID invitationId, UUID callerUserId) {
        userService.requireActiveUser(callerUserId);
        GroupInvitationEntity invitation = groupInvitationRepository.findById(invitationId)
                .orElseThrow(() -> new BusinessException(ErrorCode.GROUP_INVITATION_NOT_FOUND));

        if (!callerUserId.equals(invitation.getInviteeId())) {
            throw new BusinessException(ErrorCode.GROUP_INVITATION_NOT_FOUND);
        }

        if (invitation.getStatus() != GroupInvitationStatus.PENDING) {
            throw new BusinessException(ErrorCode.INVITATION_ALREADY_RESOLVED);
        }

        Instant now = clock.instant();
        admitMemberUnderGroupLock(invitation.getGroupId(), callerUserId);
        invitation.accept(now);
    }

    @Transactional
    public void declineInvitation(UUID invitationId, UUID callerUserId) {
        userService.requireActiveUser(callerUserId);
        GroupInvitationEntity invitation = groupInvitationRepository.findById(invitationId)
                .orElseThrow(() -> new BusinessException(ErrorCode.GROUP_INVITATION_NOT_FOUND));

        if (!callerUserId.equals(invitation.getInviteeId())) {
            throw new BusinessException(ErrorCode.GROUP_INVITATION_NOT_FOUND);
        }

        if (invitation.getStatus() != GroupInvitationStatus.PENDING) {
            throw new BusinessException(ErrorCode.INVITATION_ALREADY_RESOLVED);
        }

        invitation.decline(clock.instant());
    }

    @Transactional
    public void cancelInvitation(UUID invitationId, UUID callerUserId) {
        userService.requireActiveUser(callerUserId);
        GroupInvitationEntity invitation = groupInvitationRepository.findById(invitationId)
                .orElseThrow(() -> new BusinessException(ErrorCode.GROUP_INVITATION_NOT_FOUND));

        if (invitation.getStatus() != GroupInvitationStatus.PENDING) {
            throw new BusinessException(ErrorCode.INVITATION_ALREADY_RESOLVED);
        }

        boolean isInviter = Objects.equals(callerUserId, invitation.getInviterId());
        if (!isInviter) {
            // Must be current group OWNER or ADMIN
            groupPermissionService.requireAdminOrOwner(invitation.getGroupId(), callerUserId);
        }

        invitation.cancel(clock.instant());
    }

    // =========================================================================
    // Invite Links & Codes
    // =========================================================================
    @Transactional
    public InviteLinkResponse createInviteLink(UUID groupId, UUID callerUserId, CreateInviteLinkRequest request) {
        groupPermissionService.requireAdminOrOwner(groupId, callerUserId);
        Instant now = clock.instant();

        if (request.expiresAt() != null && !request.expiresAt().isAfter(now)) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }

        String code = generateSecureInviteCode();
        GroupInviteLinkEntity link = groupInviteLinkRepository.save(new GroupInviteLinkEntity(
                UUID.randomUUID(),
                groupId,
                code,
                callerUserId,
                request.maxUses(),
                0,
                request.expiresAt(),
                false,
                now
        ));

        return InviteLinkResponse.from(link);
    }

    @Transactional(readOnly = true)
    public List<InviteLinkResponse> getInviteLinks(UUID groupId, UUID callerUserId) {
        groupPermissionService.requireAdminOrOwner(groupId, callerUserId);
        return groupInviteLinkRepository.findByGroupIdOrderByCreatedAtDesc(groupId).stream()
                .map(InviteLinkResponse::from)
                .toList();
    }

    @Transactional
    public void revokeInviteLink(UUID linkId, UUID callerUserId) {
        GroupInviteLinkRepository.InviteLinkIdentity identity = groupInviteLinkRepository.findIdentityById(linkId)
                .orElseThrow(() -> new BusinessException(ErrorCode.INVITE_LINK_NOT_FOUND));
        UUID groupId = identity.getGroupId();
        groupRepository.findByIdForUpdate(groupId)
                .filter(group -> group.getStatus() != GroupStatus.DELETED)
                .orElseThrow(() -> new BusinessException(ErrorCode.GROUP_NOT_FOUND));
        groupPermissionService.requireAdminOrOwner(groupId, callerUserId);
        GroupInviteLinkEntity link = groupInviteLinkRepository.findByIdForUpdate(linkId)
                .orElseThrow(() -> new BusinessException(ErrorCode.INVITE_LINK_NOT_FOUND));
        link.revoke();
    }

    @Transactional(readOnly = true)
    public GroupInviteSummaryResponse resolveInviteCode(String inviteCode, UUID callerUserId) {
        userService.requireActiveUser(callerUserId);
        Instant now = clock.instant();

        GroupInviteLinkEntity link = groupInviteLinkRepository.findByCode(inviteCode)
                .orElseThrow(() -> new BusinessException(ErrorCode.INVITE_LINK_NOT_FOUND));

        if (link.isRevoked()) {
            throw new BusinessException(ErrorCode.INVITE_LINK_REVOKED);
        }
        if (link.isExpired(now)) {
            throw new BusinessException(ErrorCode.INVITE_LINK_EXPIRED);
        }
        if (link.isLimitReached()) {
            throw new BusinessException(ErrorCode.INVITE_LINK_LIMIT_REACHED);
        }

        GroupEntity group = groupRepository.findById(link.getGroupId())
                .filter(g -> g.getStatus() != GroupStatus.DELETED)
                .orElseThrow(() -> new BusinessException(ErrorCode.GROUP_NOT_FOUND));

        if (group.getStatus() == GroupStatus.ARCHIVED) {
            throw new BusinessException(ErrorCode.GROUP_ARCHIVED);
        }

        long memberCount = groupMembershipRepository.countByGroupIdAndStatus(group.getId(), GroupMembershipStatus.ACTIVE);
        GroupSettingsEntity settings = groupSettingsRepository.findById(group.getId())
                .orElseThrow(() -> new IllegalStateException("Group settings missing"));

        return GroupInviteSummaryResponse.of(group, memberCount, settings.getJoinPolicy());
    }

    @Transactional
    public Object joinViaInviteCode(String inviteCode, UUID callerUserId) {
        userService.requireActiveUser(callerUserId);
        Instant now = clock.instant();

        GroupInviteLinkRepository.InviteLinkIdentity identity = groupInviteLinkRepository.findIdentityByCode(inviteCode)
                .orElseThrow(() -> new BusinessException(ErrorCode.INVITE_LINK_NOT_FOUND));
        UUID groupId = identity.getGroupId();
        GroupEntity group = groupRepository.findByIdForUpdate(groupId)
                .filter(g -> g.getStatus() != GroupStatus.DELETED)
                .orElseThrow(() -> new BusinessException(ErrorCode.GROUP_NOT_FOUND));

        if (group.getStatus() == GroupStatus.ARCHIVED) {
            throw new BusinessException(ErrorCode.GROUP_ARCHIVED);
        }
        GroupInviteLinkEntity link = groupInviteLinkRepository.findByIdForUpdate(identity.getId())
                .filter(candidate -> candidate.getGroupId().equals(groupId) && candidate.getCode().equals(inviteCode))
                .orElseThrow(() -> new BusinessException(ErrorCode.INVITE_LINK_NOT_FOUND));
        if (link.isRevoked()) throw new BusinessException(ErrorCode.INVITE_LINK_REVOKED);
        if (link.isExpired(now)) throw new BusinessException(ErrorCode.INVITE_LINK_EXPIRED);
        if (link.isLimitReached()) throw new BusinessException(ErrorCode.INVITE_LINK_LIMIT_REACHED);

        if (groupBanRepository.existsByGroupIdAndUserIdAndUnbannedAtIsNull(groupId, callerUserId)) {
            throw new BusinessException(ErrorCode.USER_BANNED_FROM_GROUP);
        }

        if (groupMembershipRepository.findFirstByGroupIdAndUserIdAndStatus(groupId, callerUserId, GroupMembershipStatus.ACTIVE).isPresent()) {
            throw new BusinessException(ErrorCode.ALREADY_GROUP_MEMBER);
        }

        GroupSettingsEntity settings = groupSettingsRepository.findById(groupId)
                .orElseThrow(() -> new IllegalStateException("Group settings missing"));

        if (settings.getJoinPolicy() == GroupJoinPolicy.AUTO_JOIN) {
            admitMemberUnderGroupLock(groupId, callerUserId);
            link.incrementUses();
            return null;
        } else {
            // APPROVAL_REQUIRED: creates PENDING join request, does NOT increment usesCount
            if (groupJoinRequestRepository.existsByGroupIdAndUserIdAndStatus(groupId, callerUserId, GroupJoinRequestStatus.PENDING)) {
                throw new BusinessException(ErrorCode.JOIN_REQUEST_ALREADY_PENDING);
            }

            GroupJoinRequestEntity joinRequest = groupJoinRequestRepository.save(new GroupJoinRequestEntity(
                    UUID.randomUUID(),
                    groupId,
                    callerUserId,
                    GroupJoinRequestStatus.PENDING,
                    now,
                    null,
                    null
            ));

            UserEntity user = userRepository.findById(callerUserId).orElse(null);
            String displayName = user != null ? user.getDisplayName() : null;
            String avatarKey = user != null ? user.getAvatarStorageKey() : null;

            return JoinRequestResponse.of(joinRequest, group.getName(), displayName, avatarKey);
        }
    }

    // =========================================================================
    // Join Requests
    // =========================================================================
    @Transactional(readOnly = true)
    public PagedResponse<JoinRequestResponse> getJoinRequests(UUID groupId, UUID callerUserId, int page, int size) {
        ReadableGroupAccess access = groupPermissionService.requireAdminOrOwner(groupId, callerUserId);
        Page<GroupJoinRequestEntity> requests = groupJoinRequestRepository.findByGroupIdAndStatus(
                groupId,
                GroupJoinRequestStatus.PENDING,
                PageRequest.of(page, size, Sort.by("createdAt").descending())
        );

        List<JoinRequestResponse> responses = requests.getContent().stream().map(req -> {
            UserEntity user = userRepository.findById(req.getUserId()).orElse(null);
            String displayName = user != null ? user.getDisplayName() : null;
            String avatarKey = user != null ? user.getAvatarStorageKey() : null;
            return JoinRequestResponse.of(req, access.group().getName(), displayName, avatarKey);
        }).toList();

        return PagedResponse.from(requests, responses);
    }

    @Transactional
    public void approveJoinRequest(UUID requestId, UUID callerUserId) {
        GroupJoinRequestEntity request = groupJoinRequestRepository.findById(requestId)
                .orElseThrow(() -> new BusinessException(ErrorCode.JOIN_REQUEST_NOT_FOUND));

        groupPermissionService.requireAdminOrOwner(request.getGroupId(), callerUserId);

        if (request.getStatus() != GroupJoinRequestStatus.PENDING) {
            throw new BusinessException(ErrorCode.JOIN_REQUEST_ALREADY_RESOLVED);
        }

        Instant now = clock.instant();
        admitMemberUnderGroupLock(request.getGroupId(), request.getUserId());
        request.approve(callerUserId, now);
    }

    @Transactional
    public void rejectJoinRequest(UUID requestId, UUID callerUserId) {
        GroupJoinRequestEntity request = groupJoinRequestRepository.findById(requestId)
                .orElseThrow(() -> new BusinessException(ErrorCode.JOIN_REQUEST_NOT_FOUND));

        groupPermissionService.requireAdminOrOwner(request.getGroupId(), callerUserId);

        if (request.getStatus() != GroupJoinRequestStatus.PENDING) {
            throw new BusinessException(ErrorCode.JOIN_REQUEST_ALREADY_RESOLVED);
        }

        request.reject(callerUserId, clock.instant());
    }

    @Transactional
    public void cancelJoinRequest(UUID requestId, UUID callerUserId) {
        userService.requireActiveUser(callerUserId);
        GroupJoinRequestEntity request = groupJoinRequestRepository.findById(requestId)
                .orElseThrow(() -> new BusinessException(ErrorCode.JOIN_REQUEST_NOT_FOUND));

        if (!callerUserId.equals(request.getUserId())) {
            throw new BusinessException(ErrorCode.ACCESS_DENIED);
        }

        if (request.getStatus() != GroupJoinRequestStatus.PENDING) {
            throw new BusinessException(ErrorCode.JOIN_REQUEST_ALREADY_RESOLVED);
        }

        request.cancel(clock.instant());
    }

    private String generateSecureInviteCode() {
        byte[] randomBytes = new byte[9];
        SECURE_RANDOM.nextBytes(randomBytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(randomBytes);
    }
}
