package com.wedo.backend.auth.event;

import java.util.UUID;

public record PasswordResetRequestedEvent(
        UUID userId,
        String email,
        String rawCode
) {}
