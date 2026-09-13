package com.wedo.backend.user.dto;

import com.wedo.backend.user.entity.DmPolicy;
import com.wedo.backend.user.entity.FriendRequestPolicy;

public record UpdatePrivacySettingsRequest(
        Boolean discoverByUsername,
        Boolean discoverByQr,
        Boolean discoverByEmail,
        Boolean discoverByPhone,
        DmPolicy dmPolicy,
        FriendRequestPolicy friendRequestPolicy,
        Boolean showOnlineStatus,
        Boolean showLastSeen
) {
}
