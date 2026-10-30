package com.wedo.backend.group.dto;

import com.wedo.backend.group.entity.GroupEntity;
import com.wedo.backend.group.entity.GroupJoinPolicy;

import java.util.UUID;

public record GroupInviteSummaryResponse(
        UUID groupId,
        String name,
        String description,
        String avatarStorageKey,
        long memberCount,
        GroupJoinPolicy joinPolicy,
        boolean alreadyMember,
        boolean requestPending
) {
    public GroupInviteSummaryResponse(UUID groupId, String name, String description, String avatarStorageKey,
                                      long memberCount, GroupJoinPolicy joinPolicy) {
        this(groupId, name, description, avatarStorageKey, memberCount, joinPolicy, false, false);
    }

    public static GroupInviteSummaryResponse of(GroupEntity group, long memberCount, GroupJoinPolicy joinPolicy) {
        return new GroupInviteSummaryResponse(
                group.getId(),
                group.getName(),
                group.getDescription(),
                group.getAvatarStorageKey(),
                memberCount,
                joinPolicy
        );
    }
}
