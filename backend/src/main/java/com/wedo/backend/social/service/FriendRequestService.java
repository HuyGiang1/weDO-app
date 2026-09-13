package com.wedo.backend.social.service;

import com.wedo.backend.common.dto.PagedResponse;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.social.dto.FriendRequestResponse;
import com.wedo.backend.social.dto.SocialUserSummaryDto;
import com.wedo.backend.social.entity.FriendRequestEntity;
import com.wedo.backend.social.entity.FriendRequestStatus;
import com.wedo.backend.social.entity.FriendshipEntity;
import com.wedo.backend.social.repository.FriendRequestRepository;
import com.wedo.backend.social.repository.FriendshipRepository;
import com.wedo.backend.social.repository.UserBlockRepository;
import com.wedo.backend.user.entity.FriendRequestPolicy;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserPrivacySettingsEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserPrivacySettingsRepository;
import com.wedo.backend.user.repository.UserRepository;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import java.util.stream.Stream;

@Service
@Transactional
public class FriendRequestService {

    private static final Duration DECLINE_COOLDOWN = Duration.ofHours(24);

    private final FriendRequestRepository friendRequestRepository;
    private final FriendshipRepository friendshipRepository;
    private final UserBlockRepository userBlockRepository;
    private final UserRepository userRepository;
    private final UserPrivacySettingsRepository userPrivacySettingsRepository;
    private final MutualGroupChecker mutualGroupChecker;

    public FriendRequestService(
            FriendRequestRepository friendRequestRepository,
            FriendshipRepository friendshipRepository,
            UserBlockRepository userBlockRepository,
            UserRepository userRepository,
            UserPrivacySettingsRepository userPrivacySettingsRepository,
            MutualGroupChecker mutualGroupChecker
    ) {
        this.friendRequestRepository = friendRequestRepository;
        this.friendshipRepository = friendshipRepository;
        this.userBlockRepository = userBlockRepository;
        this.userRepository = userRepository;
        this.userPrivacySettingsRepository = userPrivacySettingsRepository;
        this.mutualGroupChecker = mutualGroupChecker;
    }

    public FriendRequestResponse sendFriendRequest(UUID senderId, UUID targetUserId) {
        if (senderId.equals(targetUserId)) {
            throw new BusinessException(ErrorCode.CANNOT_FRIEND_SELF);
        }

        Instant now = Instant.now();

        UserEntity sender = userRepository.findById(senderId)
                .orElseThrow(() -> new BusinessException(ErrorCode.AUTH_TOKEN_INVALID));

        UserEntity target = userRepository.findById(targetUserId)
                .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));

        if (target.getStatus() != UserStatus.ACTIVE) {
            throw new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);
        }

        if (userBlockRepository.existsBlockBetween(senderId, targetUserId)) {
            throw new BusinessException(ErrorCode.USER_BLOCKED);
        }

        if (friendshipRepository.existsActiveBetween(senderId, targetUserId)) {
            throw new BusinessException(ErrorCode.ALREADY_FRIENDS);
        }

        if (friendRequestRepository.existsPendingBetween(senderId, targetUserId)) {
            throw new BusinessException(ErrorCode.FRIEND_REQUEST_ALREADY_PENDING);
        }

        UserPrivacySettingsEntity targetPrivacy = userPrivacySettingsRepository.findById(targetUserId)
                .orElseGet(() -> UserPrivacySettingsEntity.createDefault(targetUserId, now));

        FriendRequestPolicy policy = targetPrivacy.getFriendRequestPolicy();
        if (policy == FriendRequestPolicy.NONE) {
            throw new BusinessException(ErrorCode.FRIEND_REQUEST_NOT_ALLOWED);
        }
        if (policy == FriendRequestPolicy.MUTUAL_GROUPS && !mutualGroupChecker.haveMutualActiveGroup(senderId, targetUserId)) {
            throw new BusinessException(ErrorCode.FRIEND_REQUEST_NOT_ALLOWED);
        }

        List<FriendRequestEntity> declinedRequests = friendRequestRepository.findDeclinedRequests(senderId, targetUserId);
        for (FriendRequestEntity declined : declinedRequests) {
            if (declined.getRespondedAt() != null && now.isBefore(declined.getRespondedAt().plus(DECLINE_COOLDOWN))) {
                throw new BusinessException(ErrorCode.FRIEND_REQUEST_COOLDOWN_ACTIVE);
            }
        }

        FriendRequestEntity newRequest = FriendRequestEntity.createPending(UUID.randomUUID(), senderId, targetUserId, now);
        try {
            friendRequestRepository.saveAndFlush(newRequest);
        } catch (DataIntegrityViolationException ex) {
            throw new BusinessException(ErrorCode.FRIEND_REQUEST_ALREADY_PENDING);
        }

        return FriendRequestResponse.of(
                newRequest,
                SocialUserSummaryDto.from(sender),
                SocialUserSummaryDto.from(target)
        );
    }

    @Transactional(readOnly = true)
    public PagedResponse<FriendRequestResponse> getReceivedRequests(UUID currentUserId, Pageable pageable) {
        Page<FriendRequestEntity> page = friendRequestRepository.findByReceiverIdAndStatusOrderByCreatedAtDesc(
                currentUserId, FriendRequestStatus.PENDING, pageable
        );
        return mapToPagedResponse(page);
    }

    @Transactional(readOnly = true)
    public PagedResponse<FriendRequestResponse> getSentRequests(UUID currentUserId, Pageable pageable) {
        Page<FriendRequestEntity> page = friendRequestRepository.findBySenderIdAndStatusOrderByCreatedAtDesc(
                currentUserId, FriendRequestStatus.PENDING, pageable
        );
        return mapToPagedResponse(page);
    }

    public FriendRequestResponse acceptFriendRequest(UUID currentUserId, UUID requestId) {
        Instant now = Instant.now();

        FriendRequestEntity request = friendRequestRepository.findById(requestId)
                .orElseThrow(() -> new BusinessException(ErrorCode.FRIEND_REQUEST_NOT_FOUND));

        if (!request.getReceiverId().equals(currentUserId)) {
            throw new BusinessException(ErrorCode.ACCESS_DENIED);
        }

        if (request.getStatus() != FriendRequestStatus.PENDING) {
            throw new BusinessException(ErrorCode.CONFLICT);
        }

        if (userBlockRepository.existsBlockBetween(request.getSenderId(), request.getReceiverId())) {
            throw new BusinessException(ErrorCode.USER_BLOCKED);
        }

        if (friendshipRepository.existsActiveBetween(request.getSenderId(), request.getReceiverId())) {
            throw new BusinessException(ErrorCode.ALREADY_FRIENDS);
        }

        int updated = friendRequestRepository.updateStatusAtomically(
                requestId, FriendRequestStatus.PENDING, FriendRequestStatus.ACCEPTED, now
        );
        if (updated == 0) {
            throw new BusinessException(ErrorCode.CONFLICT);
        }

        FriendshipEntity friendship = FriendshipEntity.createActive(
                UUID.randomUUID(), request.getSenderId(), request.getReceiverId(), now
        );
        friendshipRepository.saveAndFlush(friendship);

        request.setStatus(FriendRequestStatus.ACCEPTED);
        request.setRespondedAt(now);

        UserEntity sender = userRepository.findById(request.getSenderId()).orElse(null);
        UserEntity receiver = userRepository.findById(request.getReceiverId()).orElse(null);

        return FriendRequestResponse.of(
                request,
                SocialUserSummaryDto.from(sender),
                SocialUserSummaryDto.from(receiver)
        );
    }

    public void declineFriendRequest(UUID currentUserId, UUID requestId) {
        Instant now = Instant.now();

        FriendRequestEntity request = friendRequestRepository.findById(requestId)
                .orElseThrow(() -> new BusinessException(ErrorCode.FRIEND_REQUEST_NOT_FOUND));

        if (!request.getReceiverId().equals(currentUserId)) {
            throw new BusinessException(ErrorCode.ACCESS_DENIED);
        }

        if (request.getStatus() != FriendRequestStatus.PENDING) {
            throw new BusinessException(ErrorCode.CONFLICT);
        }

        int updated = friendRequestRepository.updateStatusAtomically(
                requestId, FriendRequestStatus.PENDING, FriendRequestStatus.DECLINED, now
        );
        if (updated == 0) {
            throw new BusinessException(ErrorCode.CONFLICT);
        }
    }

    public void cancelFriendRequest(UUID currentUserId, UUID requestId) {
        Instant now = Instant.now();

        FriendRequestEntity request = friendRequestRepository.findById(requestId)
                .orElseThrow(() -> new BusinessException(ErrorCode.FRIEND_REQUEST_NOT_FOUND));

        if (!request.getSenderId().equals(currentUserId)) {
            throw new BusinessException(ErrorCode.ACCESS_DENIED);
        }

        if (request.getStatus() != FriendRequestStatus.PENDING) {
            throw new BusinessException(ErrorCode.CONFLICT);
        }

        int updated = friendRequestRepository.updateStatusAtomically(
                requestId, FriendRequestStatus.PENDING, FriendRequestStatus.CANCELLED, now
        );
        if (updated == 0) {
            throw new BusinessException(ErrorCode.CONFLICT);
        }
    }

    private PagedResponse<FriendRequestResponse> mapToPagedResponse(Page<FriendRequestEntity> page) {
        Set<UUID> userIds = page.getContent().stream()
                .flatMap(r -> Stream.of(r.getSenderId(), r.getReceiverId()))
                .filter(Objects::nonNull)
                .collect(Collectors.toSet());

        Map<UUID, UserEntity> userMap = userRepository.findAllById(userIds).stream()
                .collect(Collectors.toMap(UserEntity::getId, Function.identity()));

        List<FriendRequestResponse> dtos = page.getContent().stream()
                .map(r -> FriendRequestResponse.of(
                        r,
                        SocialUserSummaryDto.from(userMap.get(r.getSenderId())),
                        SocialUserSummaryDto.from(userMap.get(r.getReceiverId()))
                ))
                .toList();

        return PagedResponse.from(page, dtos);
    }
}
