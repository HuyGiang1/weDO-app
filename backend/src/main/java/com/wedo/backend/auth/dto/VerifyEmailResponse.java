package com.wedo.backend.auth.dto;

import com.wedo.backend.user.entity.UserStatus;

import java.time.Instant;
import java.util.UUID;

public record VerifyEmailResponse(
        UUID userId,
        UserStatus status,
        Instant emailVerifiedAt,
        String nextStep
) {
    public static final String NEXT_STEP_COMPLETE_PROFILE = "COMPLETE_PROFILE";

    public static VerifyEmailResponse of(UUID userId, UserStatus status, Instant emailVerifiedAt) {
        return new VerifyEmailResponse(userId, status, emailVerifiedAt, NEXT_STEP_COMPLETE_PROFILE);
    }
}
