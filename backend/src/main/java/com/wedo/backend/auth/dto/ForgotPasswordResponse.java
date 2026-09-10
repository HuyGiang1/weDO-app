package com.wedo.backend.auth.dto;

public record ForgotPasswordResponse(
        String message
) {
    public static final String DEFAULT_MESSAGE =
            "If an account with this email exists, password reset instructions have been sent.";

    public static ForgotPasswordResponse ofDefault() {
        return new ForgotPasswordResponse(DEFAULT_MESSAGE);
    }
}
