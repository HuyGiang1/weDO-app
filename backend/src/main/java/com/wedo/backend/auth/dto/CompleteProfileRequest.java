package com.wedo.backend.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record CompleteProfileRequest(
        @NotBlank(message = "Profile completion token is required")
        String profileCompletionToken,

        @NotBlank(message = "Username is required")
        @Size(min = 3, max = 30, message = "Username must be between 3 and 30 characters")
        @Pattern(
                regexp = "^[a-zA-Z0-9_]{3,30}$",
                message = "Username must contain only letters, numbers, and underscores"
        )
        String username,

        @NotBlank(message = "Display name is required")
        @Size(max = 100, message = "Display name must not exceed 100 characters")
        String displayName,

        @Size(max = 500, message = "Bio must not exceed 500 characters")
        String bio,

        @Size(max = 255, message = "Avatar storage key must not exceed 255 characters")
        String avatarStorageKey
) {
}
