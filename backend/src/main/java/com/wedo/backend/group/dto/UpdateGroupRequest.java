package com.wedo.backend.group.dto;

import jakarta.validation.constraints.Size;

public record UpdateGroupRequest(
        @Size(max = 100, message = "Group name must not exceed 100 characters") String name,
        @Size(max = 500, message = "Group description must not exceed 500 characters") String description,
        @Size(max = 255, message = "Avatar storage key must not exceed 255 characters") String avatarStorageKey
) {
}
