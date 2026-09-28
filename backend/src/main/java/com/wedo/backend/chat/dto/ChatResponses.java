package com.wedo.backend.chat.dto;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class ChatResponses {
    private ChatResponses() { }

    public record User(UUID id, String displayName, String avatarStorageKey) { }
    public record Permissions(boolean canSend, boolean canEdit, boolean canUnsend,
                              boolean canDeleteForMe, boolean canReact, boolean canPin,
                              boolean readOnly) { }
    public record Conversation(UUID id, String type, UUID groupId, String title,
                               String avatarStorageKey,
                               User peer, String accessStatus, long lastSequence,
                               String lastMessagePreview, Instant lastMessageAt,
                               long unreadCount, Permissions permissions) { }
    public record Message(UUID id, long sequence, boolean isMine, User author, String content,
                          String status, UUID replyToMessageId, Instant createdAt,
                          Instant editedAt, Instant unsentAt, String myReaction,
                          List<Reaction> reactions, Permissions permissions) { }
    public record Reaction(String emoji, long count, boolean reactedByMe) { }
    public record Reactor(UUID id, String displayName, String avatarUrl) { }
    public record ReactionDetail(Reactor user, String emoji) { }
    public record MessagePage(UUID conversationId, List<Message> messages,
                              Long nextBeforeSequence, boolean hasMore,
                              List<ReaderState> readers) { }
    public record ReaderState(UUID userId, String displayName, String avatarStorageKey,
                              long lastReadSequence) { }
    public record MessageRequest(UUID id, UUID conversationId, User sender, User receiver,
                                String status, Instant createdAt, long messageCount) { }
    public record DirectOpen(Conversation conversation, String accessStatus) { }
}
