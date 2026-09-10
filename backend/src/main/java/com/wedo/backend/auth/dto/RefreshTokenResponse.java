package com.wedo.backend.auth.dto;

import java.time.Instant;

public record RefreshTokenResponse(
        String accessToken,
        String refreshToken,
        String tokenType,
        Instant accessTokenExpiresAt,
        Instant refreshTokenExpiresAt
) {
    public static RefreshTokenResponse of(
            String accessToken,
            String refreshToken,
            Instant accessTokenExpiresAt,
            Instant refreshTokenExpiresAt
    ) {
        return new RefreshTokenResponse(
                accessToken,
                refreshToken,
                "Bearer",
                accessTokenExpiresAt,
                refreshTokenExpiresAt
        );
    }
}
