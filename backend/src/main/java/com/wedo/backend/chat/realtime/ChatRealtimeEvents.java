package com.wedo.backend.chat.realtime;

import com.wedo.backend.chat.dto.ChatResponses;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class ChatRealtimeEvents {
    private ChatRealtimeEvents() { }

    /**
     * Client -> Server WebSocket command frame.
     */
    public record ClientCommand(
            String type,
            UUID conversationId,
            UUID messageId,
            String content,
            UUID replyToMessageId,
            UUID clientMessageId,
            String emoji,
            Long lastReadSequence
    ) { }

    /**
     * Server -> Client WebSocket event envelope.
     */
    public record ServerEvent(
            UUID eventId,
            String type,
            String eventAlias,
            UUID conversationId,
            UUID messageId,
            Long sequence,
            UUID clientMessageId,
            ChatResponses.User actor,
            ChatResponses.Message message,
            ChatResponses.ReaderState reader,
            Boolean typing,
            Boolean online,
            List<UUID> onlineUserIds,
            String errorCode,
            String errorMessage,
            Instant occurredAt
    ) { }

    /**
     * Internal Spring application event published inside @Transactional methods
     * and handled strictly in TransactionPhase.AFTER_COMMIT.
     */
    public record DomainMutationEvent(
            UUID eventId,
            String type,
            UUID conversationId,
            UUID messageId,
            Long sequence,
            UUID clientMessageId,
            UUID actorId,
            Instant occurredAt
    ) { }

    /**
     * Internal Spring application event for monotonic read-state updates,
     * handled strictly in TransactionPhase.AFTER_COMMIT.
     */
    public record DomainReadEvent(
            UUID eventId,
            UUID conversationId,
            ChatResponses.ReaderState reader,
            Instant occurredAt
    ) { }

    /**
     * Serializable envelope published across Redis pub/sub channel wedo:chat:realtime.
     */
    public record RedisFanoutEnvelope(
            UUID eventId,
            String originInstanceId,
            String type,
            UUID conversationId,
            UUID messageId,
            Long sequence,
            UUID clientMessageId,
            UUID actorId,
            ChatResponses.ReaderState reader,
            Boolean typing,
            Boolean online,
            Instant occurredAt
    ) { }
}
