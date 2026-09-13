package com.wedo.backend.social.dto;

import com.wedo.backend.social.entity.FriendRequestEntity;
import com.wedo.backend.social.entity.FriendRequestStatus;

import java.time.Instant;
import java.util.UUID;

public record FriendRequestResponse(
    UUID id,
    SocialUserSummaryDto sender,
    SocialUserSummaryDto receiver,
    FriendRequestStatus status,
    Instant createdAt,
    Instant respondedAt
) {
    public static FriendRequestResponse of(
        FriendRequestEntity entity,
        SocialUserSummaryDto sender,
        SocialUserSummaryDto receiver
    ) {
        return new FriendRequestResponse(
            entity.getId(),
            sender,
            receiver,
            entity.getStatus(),
            entity.getCreatedAt(),
            entity.getRespondedAt()
        );
    }
}
