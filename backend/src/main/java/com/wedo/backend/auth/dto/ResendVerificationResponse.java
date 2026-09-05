package com.wedo.backend.auth.dto;

import java.util.UUID;

public record ResendVerificationResponse(
        UUID userId,
        long cooldownSeconds
) {
    public static final long DEFAULT_COOLDOWN_SECONDS = 60L;

    public static ResendVerificationResponse of(UUID userId, long cooldownSeconds) {
        return new ResendVerificationResponse(userId, cooldownSeconds);
    }
}
