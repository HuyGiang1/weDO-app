package com.wedo.backend.auth.dto;

import com.wedo.backend.user.entity.UserStatus;

import java.time.Instant;
import java.util.UUID;

public record LoginResponse(
        UUID userId,
        UserStatus status,
        String nextStep,
        String profileCompletionToken,
        String accessToken,
        String refreshToken,
        String tokenType,
        Instant accessTokenExpiresAt,
        UserSummaryDto user
) {
    public static final String NEXT_STEP_COMPLETE_PROFILE = "COMPLETE_PROFILE";
    public static final String NEXT_STEP_AUTHENTICATED = "AUTHENTICATED";
    public static final String TOKEN_TYPE_BEARER = "Bearer";

    public static LoginResponse recovery(UUID userId, UserStatus status, String profileCompletionToken) {
        return new LoginResponse(
                userId,
                status,
                NEXT_STEP_COMPLETE_PROFILE,
                profileCompletionToken,
                null,
                null,
                null,
                null,
                null
        );
    }

    public static LoginResponse authenticated(
            UUID userId,
            UserStatus status,
            String accessToken,
            String refreshToken,
            Instant accessTokenExpiresAt,
            UserSummaryDto user
    ) {
        return new LoginResponse(
                userId,
                status,
                NEXT_STEP_AUTHENTICATED,
                null,
                accessToken,
                refreshToken,
                TOKEN_TYPE_BEARER,
                accessTokenExpiresAt,
                user
        );
    }
}
