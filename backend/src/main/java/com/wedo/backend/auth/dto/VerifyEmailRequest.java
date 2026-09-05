package com.wedo.backend.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;

import java.util.UUID;

public record VerifyEmailRequest(
        @NotNull(message = "User ID must not be null")
        UUID userId,

        @NotBlank(message = "Verification code must not be blank")
        @Pattern(regexp = "^\\d{6}$", message = "Verification code must be exactly 6 digits")
        String code
) {
}
