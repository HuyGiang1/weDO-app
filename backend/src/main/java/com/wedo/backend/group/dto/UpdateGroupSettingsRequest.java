package com.wedo.backend.group.dto;

import com.wedo.backend.group.entity.ChatHistoryPolicy;
import com.wedo.backend.group.entity.GroupJoinPolicy;

public record UpdateGroupSettingsRequest(
        GroupJoinPolicy joinPolicy,
        Boolean memberModifyInfoAllowed,
        Boolean memberCreateActivityAllowed,
        Boolean memberPinMessageAllowed,
        ChatHistoryPolicy chatHistoryPolicy
) {
}
