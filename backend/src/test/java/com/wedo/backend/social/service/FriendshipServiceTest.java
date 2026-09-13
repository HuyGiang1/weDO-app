package com.wedo.backend.social.service;

import com.wedo.backend.common.dto.PagedResponse;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.social.dto.FriendResponse;
import com.wedo.backend.social.entity.FriendshipEntity;
import com.wedo.backend.social.entity.FriendshipStatus;
import com.wedo.backend.social.repository.FriendshipRepository;
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
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class FriendshipServiceTest {

    @Mock
    private FriendshipRepository friendshipRepository;

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private FriendshipService friendshipService;

    private UUID userA;
    private UUID userB;
    private UserEntity userAEntity;
    private UserEntity userBEntity;

    @BeforeEach
    void setUp() {
        userA = UUID.randomUUID();
        userB = UUID.randomUUID();

        userAEntity = new UserEntity(userA, "a@example.com", "user_a", "User A", UserStatus.ACTIVE, Instant.now(), Instant.now());
        userBEntity = new UserEntity(userB, "b@example.com", "user_b", "User B", UserStatus.ACTIVE, Instant.now(), Instant.now());
    }

    @Test
    @DisplayName("Should return paginated friends list resolving friend identity from either canonical position")
    void getFriends_resolvesFriendCorrectly() {
        Pageable pageable = PageRequest.of(0, 10);
        FriendshipEntity friendship = FriendshipEntity.createActive(UUID.randomUUID(), userA, userB, Instant.now());
        Page<FriendshipEntity> page = new PageImpl<>(List.of(friendship), pageable, 1);

        when(friendshipRepository.findActiveFriendshipsByUser(userA, pageable)).thenReturn(page);
        when(userRepository.findAllById(any())).thenReturn(List.of(userBEntity));

        PagedResponse<FriendResponse> response = friendshipService.getFriends(userA, pageable);

        assertThat(response.items()).hasSize(1);
        assertThat(response.items().get(0).friend().id()).isEqualTo(userB);
        assertThat(response.items().get(0).friend().username()).isEqualTo("user_b");
    }

    @Test
    @DisplayName("Should successfully unfriend active friendship")
    void unfriend_activeFriendship_succeeds() {
        when(friendshipRepository.existsActiveBetween(userA, userB)).thenReturn(true);
        when(friendshipRepository.endActiveFriendshipBetween(eq(userA), eq(userB), any())).thenReturn(1);

        friendshipService.unfriend(userA, userB);

        verify(friendshipRepository).endActiveFriendshipBetween(eq(userA), eq(userB), any());
    }

    @Test
    @DisplayName("Should throw FRIENDSHIP_NOT_FOUND when unfriend called on non-existing friendship")
    void unfriend_nonExisting_throwsFriendshipNotFound() {
        when(friendshipRepository.existsActiveBetween(userA, userB)).thenReturn(false);

        assertThatThrownBy(() -> friendshipService.unfriend(userA, userB))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.FRIENDSHIP_NOT_FOUND));
    }
}
