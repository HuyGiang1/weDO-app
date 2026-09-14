package com.wedo.backend.group.dto;

import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.group.repository.GroupSummaryProjection;

import java.time.Instant;
import java.util.UUID;

public record GroupSummaryResponse(
        UUID id,
        String name,
        String avatarStorageKey,
        GroupStatus status,
        GroupRole callerRole,
        Instant updatedAt
) {
    public static GroupSummaryResponse from(GroupSummaryProjection projection) {
        return new GroupSummaryResponse(
                projection.getId(), projection.getName(), projection.getAvatarStorageKey(),
                GroupStatus.valueOf(projection.getStatus()), GroupRole.valueOf(projection.getCallerRole()),
                projection.getUpdatedAt()
        );
    }
}
