package com.wedo.backend.group.dto;

import com.wedo.backend.group.entity.ChatHistoryPolicy;
import com.wedo.backend.group.entity.GroupJoinPolicy;
import com.wedo.backend.group.entity.GroupSettingsEntity;

import java.time.Instant;
import java.util.UUID;

public record GroupSettingsResponse(
        UUID groupId,
        GroupJoinPolicy joinPolicy,
        boolean memberModifyInfoAllowed,
        boolean memberCreateActivityAllowed,
        boolean memberPinMessageAllowed,
        ChatHistoryPolicy chatHistoryPolicy,
        Instant updatedAt
) {
    public static GroupSettingsResponse from(GroupSettingsEntity settings) {
        return new GroupSettingsResponse(
                settings.getGroupId(), settings.getJoinPolicy(), settings.isMemberModifyInfoAllowed(),
                settings.isMemberCreateActivityAllowed(), settings.isMemberPinMessageAllowed(),
                settings.getChatHistoryPolicy(), settings.getUpdatedAt()
        );
    }
}
