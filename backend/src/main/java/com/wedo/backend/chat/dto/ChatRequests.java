package com.wedo.backend.chat.dto;

import jakarta.validation.constraints.Size;
import jakarta.validation.constraints.NotBlank;
import java.util.List;
import java.util.UUID;

public final class ChatRequests {
    private ChatRequests() { }

    public record OpenDirect(UUID userId) { }
    public record SendMessage(@Size(max = 5000) String content, UUID replyToMessageId, UUID clientMessageId,
                              @Size(max = 4) List<@Size(max = 255) String> attachmentStorageKeys) {
        public SendMessage(String content, UUID replyToMessageId, UUID clientMessageId) {
            this(content, replyToMessageId, clientMessageId, null);
        }
        public SendMessage(String content, UUID replyToMessageId) {
            this(content, replyToMessageId, null, null);
        }
    }
    public record EditMessage(@NotBlank @Size(max = 5000) String content) { }
    public record ReadState(long lastReadSequence) { }
    public record Reaction(@NotBlank @Size(max = 8) String emoji) { }
}
