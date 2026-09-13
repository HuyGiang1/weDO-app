package com.wedo.backend.user.dto;

import com.wedo.backend.user.entity.DmPolicy;
import com.wedo.backend.user.entity.FriendRequestPolicy;
import com.wedo.backend.user.entity.UserPrivacySettingsEntity;

public record PrivacySettingsResponse(
        boolean discoverByUsername,
        boolean discoverByQr,
        boolean discoverByEmail,
        boolean discoverByPhone,
        DmPolicy dmPolicy,
        FriendRequestPolicy friendRequestPolicy,
        boolean showOnlineStatus,
        boolean showLastSeen
) {
    public static PrivacySettingsResponse from(UserPrivacySettingsEntity settings) {
        return new PrivacySettingsResponse(
                settings.isDiscoverByUsername(),
                settings.isDiscoverByQr(),
                settings.isDiscoverByEmail(),
                settings.isDiscoverByPhone(),
                settings.getDmPolicy(),
                settings.getFriendRequestPolicy(),
                settings.isShowOnlineStatus(),
                settings.isShowLastSeen()
        );
    }
}
