package com.wedo.backend.group.dto;

import com.wedo.backend.group.entity.GroupBanEntity;

import java.time.Instant;
import java.util.UUID;

public record GroupBanResponse(
        UUID id,
        UUID groupId,
        UUID userId,
        String username,
        String displayName,
        String avatarStorageKey,
        UUID bannedBy,
        String reason,
        Instant createdAt
) {
    public static GroupBanResponse of(
            GroupBanEntity ban,
            String username,
            String displayName,
            String avatarStorageKey
    ) {
        return new GroupBanResponse(
                ban.getId(),
                ban.getGroupId(),
                ban.getUserId(),
                username,
                displayName,
                avatarStorageKey,
                ban.getBannedBy(),
                ban.getReason(),
                ban.getCreatedAt()
        );
    }
}
