package com.wedo.backend.group.dto;

import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.repository.GroupMemberProjection;

import java.time.Instant;
import java.util.UUID;

public record GroupMemberResponse(
        UUID userId,
        String username,
        String displayName,
        String avatarStorageKey,
        GroupRole role,
        Instant joinedAt
) {
    public static GroupMemberResponse from(GroupMemberProjection projection) {
        return new GroupMemberResponse(
                projection.getUserId(), projection.getUsername(), projection.getDisplayName(),
                projection.getAvatarStorageKey(), GroupRole.valueOf(projection.getRole()), projection.getJoinedAt()
        );
    }
}
