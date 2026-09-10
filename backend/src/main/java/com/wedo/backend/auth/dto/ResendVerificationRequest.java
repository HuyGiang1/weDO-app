package com.wedo.backend.auth.dto;

import jakarta.validation.constraints.NotNull;

import java.util.UUID;

public record ResendVerificationRequest(
        @NotNull(message = "User ID must not be null")
        UUID userId
) {
}
