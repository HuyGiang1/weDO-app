package com.wedo.backend.social.service;

import com.wedo.backend.common.dto.PagedResponse;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.social.dto.FriendResponse;
import com.wedo.backend.social.dto.SocialUserSummaryDto;
import com.wedo.backend.social.entity.FriendshipEntity;
import com.wedo.backend.social.repository.FriendshipRepository;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.repository.UserRepository;
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
public class FriendshipService {

    private final FriendshipRepository friendshipRepository;
    private final UserRepository userRepository;

    public FriendshipService(
            FriendshipRepository friendshipRepository,
            UserRepository userRepository
    ) {
        this.friendshipRepository = friendshipRepository;
        this.userRepository = userRepository;
    }

    @Transactional(readOnly = true)
    public PagedResponse<FriendResponse> getFriends(UUID currentUserId, Pageable pageable) {
        Page<FriendshipEntity> page = friendshipRepository.findActiveFriendshipsByUser(currentUserId, pageable);

        Set<UUID> friendIds = page.getContent().stream()
                .map(f -> f.getUserId1().equals(currentUserId) ? f.getUserId2() : f.getUserId1())
                .collect(Collectors.toSet());

        Map<UUID, UserEntity> userMap = userRepository.findAllById(friendIds).stream()
                .collect(Collectors.toMap(UserEntity::getId, Function.identity()));

        List<FriendResponse> dtos = page.getContent().stream()
                .map(f -> {
                    UUID friendId = f.getUserId1().equals(currentUserId) ? f.getUserId2() : f.getUserId1();
                    UserEntity friendUser = userMap.get(friendId);
                    return FriendResponse.of(f, SocialUserSummaryDto.from(friendUser));
                })
                .toList();

        return PagedResponse.from(page, dtos);
    }

    public void unfriend(UUID currentUserId, UUID targetUserId) {
        Instant now = Instant.now();

        if (!friendshipRepository.existsActiveBetween(currentUserId, targetUserId)) {
            throw new BusinessException(ErrorCode.FRIENDSHIP_NOT_FOUND);
        }

        int updated = friendshipRepository.endActiveFriendshipBetween(currentUserId, targetUserId, now);
        if (updated == 0) {
            throw new BusinessException(ErrorCode.FRIENDSHIP_NOT_FOUND);
        }
    }
}
