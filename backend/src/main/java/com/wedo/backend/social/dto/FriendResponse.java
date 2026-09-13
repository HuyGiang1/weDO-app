package com.wedo.backend.social.dto;

import com.wedo.backend.social.entity.FriendshipEntity;

import java.time.Instant;
import java.util.UUID;

public record FriendResponse(
    UUID id,
    SocialUserSummaryDto friend,
    Instant since
) {
    public static FriendResponse of(FriendshipEntity friendship, SocialUserSummaryDto friend) {
        return new FriendResponse(
            friendship.getId(),
            friend,
            friendship.getCreatedAt()
        );
    }
}
