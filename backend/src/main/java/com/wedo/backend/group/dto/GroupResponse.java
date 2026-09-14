package com.wedo.backend.group.dto;

import com.wedo.backend.group.entity.GroupEntity;
import com.wedo.backend.group.entity.GroupStatus;

import java.time.Instant;
import java.util.UUID;

public record GroupResponse(
        UUID id,
        String name,
        String description,
        String avatarStorageKey,
        GroupStatus status,
        UUID createdBy,
        Instant createdAt,
        Instant updatedAt
) {
    public static GroupResponse from(GroupEntity group) {
        return new GroupResponse(
                group.getId(),
                group.getName(),
                group.getDescription(),
                group.getAvatarStorageKey(),
                group.getStatus(),
                group.getCreatedBy(),
                group.getCreatedAt(),
                group.getUpdatedAt()
        );
    }
}
