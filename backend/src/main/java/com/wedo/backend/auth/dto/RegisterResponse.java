package com.wedo.backend.auth.dto;

import com.wedo.backend.user.entity.UserStatus;

import java.util.UUID;

public record RegisterResponse(
        UUID userId,
        String email,
        UserStatus status,
        String nextStep
) {
    public static final String NEXT_STEP_VERIFY_EMAIL = "VERIFY_EMAIL";

    public static RegisterResponse of(UUID userId, String email, UserStatus status) {
        return new RegisterResponse(userId, email, status, NEXT_STEP_VERIFY_EMAIL);
    }
}
