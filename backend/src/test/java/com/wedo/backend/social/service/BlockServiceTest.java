package com.wedo.backend.social.service;

import com.wedo.backend.common.dto.PagedResponse;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.social.dto.BlockedUserResponse;
import com.wedo.backend.social.entity.UserBlockEntity;
import com.wedo.backend.social.repository.FriendRequestRepository;
import com.wedo.backend.social.repository.FriendshipRepository;
import com.wedo.backend.social.repository.UserBlockRepository;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class BlockServiceTest {

    @Mock
    private UserBlockRepository userBlockRepository;

    @Mock
    private FriendshipRepository friendshipRepository;

    @Mock
    private FriendRequestRepository friendRequestRepository;

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private BlockService blockService;

    private UUID blockerId;
    private UUID blockedId;
    private UserEntity blockedUser;

    @BeforeEach
    void setUp() {
        blockerId = UUID.randomUUID();
        blockedId = UUID.randomUUID();

        blockedUser = new UserEntity(blockedId, "blocked@example.com", "blocked_user", "Blocked Display", UserStatus.ACTIVE, Instant.now(), Instant.now());
    }

    @Test
    @DisplayName("Should throw CANNOT_BLOCK_SELF when user attempts to block own account")
    void blockUser_selfBlock_throwsCannotBlockSelf() {
        assertThatThrownBy(() -> blockService.blockUser(blockerId, blockerId))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.CANNOT_BLOCK_SELF));

        verify(userBlockRepository, never()).saveAndFlush(any());
    }

    @Test
    @DisplayName("Should throw RESOURCE_NOT_FOUND when target user does not exist")
    void blockUser_targetNotFound_throwsResourceNotFound() {
        when(userRepository.findById(blockedId)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> blockService.blockUser(blockerId, blockedId))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.RESOURCE_NOT_FOUND));
    }

    @Test
    @DisplayName("Should create block, end active friendship, and cancel pending requests in both directions")
    void blockUser_valid_endsFriendshipAndCancelsRequests() {
        when(userRepository.findById(blockedId)).thenReturn(Optional.of(blockedUser));
        when(userBlockRepository.existsByBlockerIdAndBlockedId(blockerId, blockedId)).thenReturn(false);

        blockService.blockUser(blockerId, blockedId);

        verify(userBlockRepository).saveAndFlush(any());
        verify(friendshipRepository).endActiveFriendshipBetween(eq(blockerId), eq(blockedId), any());
        verify(friendRequestRepository).cancelPendingBetween(eq(blockerId), eq(blockedId), any());
    }

    @Test
    @DisplayName("Should be idempotent when user is already blocked")
    void blockUser_alreadyBlocked_isIdempotent() {
        when(userRepository.findById(blockedId)).thenReturn(Optional.of(blockedUser));
        when(userBlockRepository.existsByBlockerIdAndBlockedId(blockerId, blockedId)).thenReturn(true);

        blockService.blockUser(blockerId, blockedId);

        verify(userBlockRepository, never()).saveAndFlush(any());
        verify(friendshipRepository, never()).endActiveFriendshipBetween(any(), any(), any());
    }

    @Test
    @DisplayName("Should unblock user without restoring friendship")
    void unblockUser_removesBlock() {
        blockService.unblockUser(blockerId, blockedId);

        verify(userBlockRepository).deleteByBlockerIdAndBlockedId(blockerId, blockedId);
        verify(friendshipRepository, never()).saveAndFlush(any());
    }

    @Test
    @DisplayName("Should return paginated list of blocked users")
    void getBlockedUsers_returnsPagedResponse() {
        Pageable pageable = PageRequest.of(0, 10);
        UserBlockEntity block = new UserBlockEntity(UUID.randomUUID(), blockerId, blockedId, Instant.now());
        Page<UserBlockEntity> page = new PageImpl<>(List.of(block), pageable, 1);

        when(userBlockRepository.findByBlockerIdOrderByCreatedAtDesc(blockerId, pageable)).thenReturn(page);
        when(userRepository.findAllById(any())).thenReturn(List.of(blockedUser));

        PagedResponse<BlockedUserResponse> response = blockService.getBlockedUsers(blockerId, pageable);

        assertThat(response.items()).hasSize(1);
        assertThat(response.items().get(0).blockedUser().username()).isEqualTo("blocked_user");
    }
}
