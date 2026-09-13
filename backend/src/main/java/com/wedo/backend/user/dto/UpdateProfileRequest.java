package com.wedo.backend.user.dto;

import jakarta.validation.constraints.Size;

/**
 * Allow-list request DTO for mutable self-profile fields.
 *
 * Null values intentionally mean unchanged for this PATCH contract.
 */
public record UpdateProfileRequest(
        @Size(max = 100, message = "Display name must not exceed 100 characters")
        String displayName,

        @Size(max = 500, message = "Bio must not exceed 500 characters")
        String bio,

        @Size(max = 20, message = "Phone must not exceed 20 characters")
        String phone,

        @Size(max = 255, message = "Avatar storage key must not exceed 255 characters")
        String avatarStorageKey
) {
}
