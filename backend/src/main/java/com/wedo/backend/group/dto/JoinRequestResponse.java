package com.wedo.backend.group.dto;

import com.wedo.backend.group.entity.GroupJoinRequestEntity;
import com.wedo.backend.group.entity.GroupJoinRequestStatus;

import java.time.Instant;
import java.util.UUID;

public record JoinRequestResponse(
        UUID id,
        UUID groupId,
        String groupName,
        UUID userId,
        String userDisplayName,
        String userAvatarStorageKey,
        GroupJoinRequestStatus status,
        Instant createdAt,
        Instant respondedAt,
        UUID respondedBy
) {
    public static JoinRequestResponse of(
            GroupJoinRequestEntity request,
            String groupName,
            String userDisplayName,
            String userAvatarStorageKey
    ) {
        return new JoinRequestResponse(
                request.getId(),
                request.getGroupId(),
                groupName,
                request.getUserId(),
                userDisplayName,
                userAvatarStorageKey,
                request.getStatus(),
                request.getCreatedAt(),
                request.getRespondedAt(),
                request.getRespondedBy()
        );
    }
}
