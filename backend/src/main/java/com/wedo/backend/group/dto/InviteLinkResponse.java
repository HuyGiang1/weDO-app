package com.wedo.backend.group.dto;

import com.wedo.backend.group.entity.GroupInviteLinkEntity;

import java.time.Instant;
import java.util.UUID;

public record InviteLinkResponse(
        UUID id,
        UUID groupId,
        String code,
        UUID createdBy,
        Integer maxUses,
        int usesCount,
        Instant expiresAt,
        boolean isRevoked,
        Instant createdAt
) {
    public static InviteLinkResponse from(GroupInviteLinkEntity entity) {
        return new InviteLinkResponse(
                entity.getId(),
                entity.getGroupId(),
                entity.getCode(),
                entity.getCreatedBy(),
                entity.getMaxUses(),
                entity.getUsesCount(),
                entity.getExpiresAt(),
                entity.isRevoked(),
                entity.getCreatedAt()
        );
    }
}
