package com.wedo.backend.group.dto;

import com.wedo.backend.group.entity.GroupActivityLogEntity;
import java.time.Instant;
import java.util.UUID;

public record GroupActivityLogResponse(UUID id, String action, UUID actorUserId, UUID targetUserId, Instant createdAt) {
    public static GroupActivityLogResponse from(GroupActivityLogEntity log) {
        return new GroupActivityLogResponse(log.getId(), log.getAction().name(), log.getActorId(), log.getTargetUserId(), log.getCreatedAt());
    }
}
