package com.wedo.backend.chat.dto;

import jakarta.validation.constraints.Size;
import jakarta.validation.constraints.NotBlank;
import java.util.UUID;

public final class ChatRequests {
    private ChatRequests() { }

    public record OpenDirect(UUID userId) { }
    public record SendMessage(@NotBlank @Size(max = 5000) String content, UUID replyToMessageId) { }
    public record EditMessage(@NotBlank @Size(max = 5000) String content) { }
    public record ReadState(long lastReadSequence) { }
    public record Reaction(@NotBlank @Size(max = 8) String emoji) { }
}
