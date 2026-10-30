package com.wedo.backend.poll.dto;
import java.util.UUID;
public record PollParticipant(UUID id, String displayName, String avatarStorageKey) { }
