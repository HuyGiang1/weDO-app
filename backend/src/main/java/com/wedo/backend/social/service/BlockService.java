package com.wedo.backend.social.service;

import com.wedo.backend.common.dto.PagedResponse;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.social.dto.BlockedUserResponse;
import com.wedo.backend.social.dto.SocialUserSummaryDto;
import com.wedo.backend.social.entity.UserBlockEntity;
import com.wedo.backend.social.repository.FriendRequestRepository;
import com.wedo.backend.social.repository.FriendshipRepository;
import com.wedo.backend.social.repository.UserBlockRepository;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserRepository;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
@Transactional
public class BlockService {

    private final UserBlockRepository userBlockRepository;
    private final FriendshipRepository friendshipRepository;
    private final FriendRequestRepository friendRequestRepository;
    private final UserRepository userRepository;

    public BlockService(
            UserBlockRepository userBlockRepository,
            FriendshipRepository friendshipRepository,
            FriendRequestRepository friendRequestRepository,
            UserRepository userRepository
    ) {
        this.userBlockRepository = userBlockRepository;
        this.friendshipRepository = friendshipRepository;
        this.friendRequestRepository = friendRequestRepository;
        this.userRepository = userRepository;
    }

    public void blockUser(UUID currentUserId, UUID targetUserId) {
        if (currentUserId.equals(targetUserId)) {
            throw new BusinessException(ErrorCode.CANNOT_BLOCK_SELF);
        }

        Instant now = Instant.now();

        UserEntity target = userRepository.findById(targetUserId)
                .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));

        if (target.getStatus() != UserStatus.ACTIVE) {
            throw new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);
        }

        if (userBlockRepository.existsByBlockerIdAndBlockedId(currentUserId, targetUserId)) {
            return;
        }

        UserBlockEntity block = new UserBlockEntity(UUID.randomUUID(), currentUserId, targetUserId, now);
        try {
            userBlockRepository.saveAndFlush(block);
        } catch (DataIntegrityViolationException ex) {
            return;
        }

        friendshipRepository.endActiveFriendshipBetween(currentUserId, targetUserId, now);
        friendRequestRepository.cancelPendingBetween(currentUserId, targetUserId, now);
    }

    public void unblockUser(UUID currentUserId, UUID targetUserId) {
        userBlockRepository.deleteByBlockerIdAndBlockedId(currentUserId, targetUserId);
    }

    @Transactional(readOnly = true)
    public PagedResponse<BlockedUserResponse> getBlockedUsers(UUID currentUserId, Pageable pageable) {
        Page<UserBlockEntity> page = userBlockRepository.findByBlockerIdOrderByCreatedAtDesc(currentUserId, pageable);

        Set<UUID> blockedUserIds = page.getContent().stream()
                .map(UserBlockEntity::getBlockedId)
                .collect(Collectors.toSet());

        Map<UUID, UserEntity> userMap = userRepository.findAllById(blockedUserIds).stream()
                .collect(Collectors.toMap(UserEntity::getId, Function.identity()));

        List<BlockedUserResponse> dtos = page.getContent().stream()
                .map(b -> {
                    UserEntity blockedUser = userMap.get(b.getBlockedId());
                    return BlockedUserResponse.of(b, SocialUserSummaryDto.from(blockedUser));
                })
                .toList();

        return PagedResponse.from(page, dtos);
    }
}
