package com.wedo.backend.group.dto;

import com.wedo.backend.group.entity.GroupEntity;
import com.wedo.backend.group.entity.GroupRole;

import java.time.Instant;
import java.util.UUID;

public record GroupDetailResponse(
        UUID id,
        String name,
        String description,
        String avatarStorageKey,
        com.wedo.backend.group.entity.GroupStatus status,
        UUID ownerUserId,
        GroupRole callerRole,
        Instant createdAt,
        Instant updatedAt
) {
    public static GroupDetailResponse of(GroupEntity group, UUID ownerUserId, GroupRole callerRole) {
        return new GroupDetailResponse(
                group.getId(), group.getName(), group.getDescription(), group.getAvatarStorageKey(), group.getStatus(),
                ownerUserId, callerRole, group.getCreatedAt(), group.getUpdatedAt()
        );
    }
}
