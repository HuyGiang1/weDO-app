package com.wedo.backend.realtime;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

/** A best-effort invalidation, not a durable log or a viewer-independent DTO. */
public record DomainRealtimeEvent(
        UUID eventId, String type, String eventType, String aggregateType,
        UUID aggregateId, UUID groupId, UUID actorId, String scope,
        Instant occurredAt, Map<String, String> payload) {
    public static DomainRealtimeEvent changed(String eventType, String aggregateType,
            UUID aggregateId, UUID groupId, UUID actorId, String scope) {
        return new DomainRealtimeEvent(UUID.randomUUID(), "DOMAIN_CHANGED", eventType,
                aggregateType, aggregateId, groupId, actorId, scope, Instant.now(), Map.of());
    }
}
