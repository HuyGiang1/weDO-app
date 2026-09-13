package com.wedo.backend.social.dto;

import com.wedo.backend.social.entity.UserBlockEntity;

import java.time.Instant;
import java.util.UUID;

public record BlockedUserResponse(
    UUID id,
    SocialUserSummaryDto blockedUser,
    Instant blockedAt
) {
    public static BlockedUserResponse of(UserBlockEntity block, SocialUserSummaryDto blockedUser) {
        return new BlockedUserResponse(
            block.getId(),
            blockedUser,
            block.getCreatedAt()
        );
    }
}
