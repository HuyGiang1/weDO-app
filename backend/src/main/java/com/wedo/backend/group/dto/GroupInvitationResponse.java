package com.wedo.backend.group.dto;

import com.wedo.backend.group.entity.GroupInvitationEntity;
import com.wedo.backend.group.entity.GroupInvitationStatus;

import java.time.Instant;
import java.util.UUID;

public record GroupInvitationResponse(
        UUID id,
        UUID groupId,
        String groupName,
        String groupAvatarStorageKey,
        UUID inviterId,
        String inviterDisplayName,
        UUID inviteeId,
        GroupInvitationStatus status,
        Instant createdAt,
        Instant respondedAt
) {
    public static GroupInvitationResponse of(
            GroupInvitationEntity invitation,
            String groupName,
            String groupAvatarStorageKey,
            String inviterDisplayName
    ) {
        return new GroupInvitationResponse(
                invitation.getId(),
                invitation.getGroupId(),
                groupName,
                groupAvatarStorageKey,
                invitation.getInviterId(),
                inviterDisplayName,
                invitation.getInviteeId(),
                invitation.getStatus(),
                invitation.getCreatedAt(),
                invitation.getRespondedAt()
        );
    }
}
