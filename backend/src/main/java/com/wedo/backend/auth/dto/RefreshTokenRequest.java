package com.wedo.backend.auth.dto;

import jakarta.validation.constraints.NotBlank;

public record RefreshTokenRequest(
        @NotBlank(message = "Refresh token must not be blank")
        String refreshToken
) {
    @Override
    public String toString() {
        return "RefreshTokenRequest[refreshToken=<redacted>]";
    }
}
