package com.wedo.backend.user.dto;

import jakarta.validation.constraints.NotBlank;

public record UpdateUsernameRequest(
        @NotBlank(message = "Username is required")
        String username
) {
}
