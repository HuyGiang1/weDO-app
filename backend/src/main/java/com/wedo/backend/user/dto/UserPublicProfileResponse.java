package com.wedo.backend.user.dto;

import com.wedo.backend.user.entity.UserEntity;

import java.util.UUID;

/** Safe public projection for an ACTIVE target addressed by its UUID. */
public record UserPublicProfileResponse(
        UUID id,
        String username,
        String displayName,
        String avatarStorageKey,
        String bio
) {
    public static UserPublicProfileResponse from(UserEntity user) {
        return new UserPublicProfileResponse(
                user.getId(),
                user.getUsername(),
                user.getDisplayName(),
                user.getAvatarStorageKey(),
                user.getBio()
        );
    }
}
