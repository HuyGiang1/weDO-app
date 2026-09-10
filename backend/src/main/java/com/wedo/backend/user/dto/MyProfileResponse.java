package com.wedo.backend.user.dto;

import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserStatus;

import java.util.UUID;

public record MyProfileResponse(
        UUID id,
        String username,
        String email,
        String phone,
        String displayName,
        String avatarStorageKey,
        String bio,
        UserStatus status,
        boolean emailVerified
) {
    public static MyProfileResponse from(UserEntity user) {
        return new MyProfileResponse(
                user.getId(),
                user.getUsername(),
                user.getEmail(),
                user.getPhone(),
                user.getDisplayName(),
                user.getAvatarStorageKey(),
                user.getBio(),
                user.getStatus(),
                user.getEmailVerifiedAt() != null
        );
    }
}
