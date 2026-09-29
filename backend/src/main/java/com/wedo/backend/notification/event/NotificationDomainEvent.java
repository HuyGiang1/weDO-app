package com.wedo.backend.notification.event;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

public record NotificationDomainEvent(
        String eventKey,
        String eventType,
        String category,
        String priority,
        boolean critical,
        UUID actorId,
        UUID groupId,
        List<UUID> recipientUserIds,
        String title,
        String body,
        String targetType,
        UUID targetId,
        String route,
        Map<String, Object> metadata,
        Instant occurredAt
) {
}
