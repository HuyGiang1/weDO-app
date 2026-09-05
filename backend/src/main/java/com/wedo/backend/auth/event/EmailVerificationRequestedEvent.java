package com.wedo.backend.auth.event;

import java.util.UUID;

public record EmailVerificationRequestedEvent(
        UUID userId,
        String email,
        String rawCode
) {}
