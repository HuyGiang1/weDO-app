package com.wedo.backend.auth.dto;

import com.wedo.backend.user.entity.UserStatus;

import java.util.UUID;

public record CompleteProfileResponse(
        UUID userId,
        String username,
        String displayName,
        UserStatus status,
        String nextStep
) {
    public static final String NEXT_STEP_LOGIN = "LOGIN";

    public static CompleteProfileResponse of(UUID userId, String username, String displayName, UserStatus status) {
        return new CompleteProfileResponse(userId, username, displayName, status, NEXT_STEP_LOGIN);
    }
}
