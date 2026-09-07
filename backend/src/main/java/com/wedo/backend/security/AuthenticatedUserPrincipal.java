package com.wedo.backend.security;

import java.util.UUID;

public record AuthenticatedUserPrincipal(
        UUID userId
) {
    public AuthenticatedUserPrincipal {
        if (userId == null) {
            throw new IllegalArgumentException("userId must not be null");
        }
    }
}
