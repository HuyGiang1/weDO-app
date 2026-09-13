package com.wedo.backend.social.dto;

import com.wedo.backend.user.entity.UserEntity;

import java.util.UUID;

public record SocialUserSummaryDto(
    UUID id,
    String username,
    String displayName,
    String avatarStorageKey
) {
    public static SocialUserSummaryDto from(UserEntity user) {
        if (user == null) {
            return null;
        }
        return new SocialUserSummaryDto(
            user.getId(),
            user.getUsername(),
            user.getDisplayName(),
            user.getAvatarStorageKey()
        );
    }
}
