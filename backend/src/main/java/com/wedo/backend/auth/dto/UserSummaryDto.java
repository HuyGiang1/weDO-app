package com.wedo.backend.auth.dto;

import java.util.UUID;

public record UserSummaryDto(
        UUID id,
        String email,
        String username,
        String displayName,
        String avatarStorageKey
) {}
