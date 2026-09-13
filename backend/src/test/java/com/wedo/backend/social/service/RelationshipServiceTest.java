package com.wedo.backend.social.service;

import com.wedo.backend.social.dto.RelationshipState;
import com.wedo.backend.social.entity.FriendRequestEntity;
import com.wedo.backend.social.repository.FriendRequestRepository;
import com.wedo.backend.social.repository.FriendshipRepository;
import com.wedo.backend.social.repository.UserBlockRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class RelationshipServiceTest {

    @Mock
    private UserBlockRepository userBlockRepository;

    @Mock
    private FriendshipRepository friendshipRepository;

    @Mock
    private FriendRequestRepository friendRequestRepository;

    @InjectMocks
    private RelationshipService relationshipService;

    private UUID userA;
    private UUID userB;

    @BeforeEach
    void setUp() {
        userA = UUID.randomUUID();
        userB = UUID.randomUUID();
    }

    @Test
    @DisplayName("Should return SELF when target user equals current user")
    void getRelationship_self() {
        assertThat(relationshipService.getRelationshipState(userA, userA)).isEqualTo(RelationshipState.SELF);
    }

    @Test
    @DisplayName("Should return BLOCKED when current user blocked target")
    void getRelationship_blocked() {
        when(userBlockRepository.existsByBlockerIdAndBlockedId(userA, userB)).thenReturn(true);
        assertThat(relationshipService.getRelationshipState(userA, userB)).isEqualTo(RelationshipState.BLOCKED);
    }

    @Test
    @DisplayName("Should return BLOCKED_BY when target user blocked current user")
    void getRelationship_blockedBy() {
        when(userBlockRepository.existsByBlockerIdAndBlockedId(userA, userB)).thenReturn(false);
        when(userBlockRepository.existsByBlockerIdAndBlockedId(userB, userA)).thenReturn(true);
        assertThat(relationshipService.getRelationshipState(userA, userB)).isEqualTo(RelationshipState.BLOCKED_BY);
    }

    @Test
    @DisplayName("Should return FRIENDS when active friendship exists")
    void getRelationship_friends() {
        when(userBlockRepository.existsByBlockerIdAndBlockedId(userA, userB)).thenReturn(false);
        when(userBlockRepository.existsByBlockerIdAndBlockedId(userB, userA)).thenReturn(false);
        when(friendshipRepository.existsActiveBetween(userA, userB)).thenReturn(true);
        assertThat(relationshipService.getRelationshipState(userA, userB)).isEqualTo(RelationshipState.FRIENDS);
    }

    @Test
    @DisplayName("Should return PENDING_SENT when pending request was sent by current user")
    void getRelationship_pendingSent() {
        when(userBlockRepository.existsByBlockerIdAndBlockedId(userA, userB)).thenReturn(false);
        when(userBlockRepository.existsByBlockerIdAndBlockedId(userB, userA)).thenReturn(false);
        when(friendshipRepository.existsActiveBetween(userA, userB)).thenReturn(false);

        FriendRequestEntity req = FriendRequestEntity.createPending(UUID.randomUUID(), userA, userB, Instant.now());
        when(friendRequestRepository.findPendingBetween(userA, userB)).thenReturn(Optional.of(req));

        assertThat(relationshipService.getRelationshipState(userA, userB)).isEqualTo(RelationshipState.PENDING_SENT);
    }

    @Test
    @DisplayName("Should return PENDING_RECEIVED when pending request was received from target user")
    void getRelationship_pendingReceived() {
        when(userBlockRepository.existsByBlockerIdAndBlockedId(userA, userB)).thenReturn(false);
        when(userBlockRepository.existsByBlockerIdAndBlockedId(userB, userA)).thenReturn(false);
        when(friendshipRepository.existsActiveBetween(userA, userB)).thenReturn(false);

        FriendRequestEntity req = FriendRequestEntity.createPending(UUID.randomUUID(), userB, userA, Instant.now());
        when(friendRequestRepository.findPendingBetween(userA, userB)).thenReturn(Optional.of(req));

        assertThat(relationshipService.getRelationshipState(userA, userB)).isEqualTo(RelationshipState.PENDING_RECEIVED);
    }

    @Test
    @DisplayName("Should return NONE when no relationship exists")
    void getRelationship_none() {
        when(userBlockRepository.existsByBlockerIdAndBlockedId(userA, userB)).thenReturn(false);
        when(userBlockRepository.existsByBlockerIdAndBlockedId(userB, userA)).thenReturn(false);
        when(friendshipRepository.existsActiveBetween(userA, userB)).thenReturn(false);
        when(friendRequestRepository.findPendingBetween(userA, userB)).thenReturn(Optional.empty());

        assertThat(relationshipService.getRelationshipState(userA, userB)).isEqualTo(RelationshipState.NONE);
    }
}
