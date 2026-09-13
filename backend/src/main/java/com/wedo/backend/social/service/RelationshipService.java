package com.wedo.backend.social.service;

import com.wedo.backend.social.dto.RelationshipState;
import com.wedo.backend.social.entity.FriendRequestEntity;
import com.wedo.backend.social.repository.FriendRequestRepository;
import com.wedo.backend.social.repository.FriendshipRepository;
import com.wedo.backend.social.repository.UserBlockRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;
import java.util.UUID;

@Service
@Transactional(readOnly = true)
public class RelationshipService {

    private final UserBlockRepository userBlockRepository;
    private final FriendshipRepository friendshipRepository;
    private final FriendRequestRepository friendRequestRepository;

    public RelationshipService(
            UserBlockRepository userBlockRepository,
            FriendshipRepository friendshipRepository,
            FriendRequestRepository friendRequestRepository
    ) {
        this.userBlockRepository = userBlockRepository;
        this.friendshipRepository = friendshipRepository;
        this.friendRequestRepository = friendRequestRepository;
    }

    public RelationshipState getRelationshipState(UUID currentUserId, UUID targetUserId) {
        if (currentUserId.equals(targetUserId)) {
            return RelationshipState.SELF;
        }

        if (userBlockRepository.existsByBlockerIdAndBlockedId(currentUserId, targetUserId)) {
            return RelationshipState.BLOCKED;
        }

        if (userBlockRepository.existsByBlockerIdAndBlockedId(targetUserId, currentUserId)) {
            return RelationshipState.BLOCKED_BY;
        }

        if (friendshipRepository.existsActiveBetween(currentUserId, targetUserId)) {
            return RelationshipState.FRIENDS;
        }

        Optional<FriendRequestEntity> pendingOpt = friendRequestRepository.findPendingBetween(currentUserId, targetUserId);
        if (pendingOpt.isPresent()) {
            FriendRequestEntity pending = pendingOpt.get();
            if (pending.getSenderId().equals(currentUserId)) {
                return RelationshipState.PENDING_SENT;
            } else {
                return RelationshipState.PENDING_RECEIVED;
            }
        }

        return RelationshipState.NONE;
    }
}
