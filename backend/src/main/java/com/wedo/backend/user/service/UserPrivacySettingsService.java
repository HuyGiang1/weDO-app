package com.wedo.backend.user.service;

import com.wedo.backend.user.dto.PrivacySettingsResponse;
import com.wedo.backend.user.dto.UpdatePrivacySettingsRequest;
import com.wedo.backend.user.entity.UserPrivacySettingsEntity;
import com.wedo.backend.user.repository.UserPrivacySettingsRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.util.UUID;

@Service
@Transactional(readOnly = true)
public class UserPrivacySettingsService {

    private final UserService userService;
    private final UserPrivacySettingsRepository userPrivacySettingsRepository;
    private final Clock clock;

    public UserPrivacySettingsService(
            UserService userService,
            UserPrivacySettingsRepository userPrivacySettingsRepository,
            Clock clock
    ) {
        this.userService = userService;
        this.userPrivacySettingsRepository = userPrivacySettingsRepository;
        this.clock = clock;
    }

    public PrivacySettingsResponse getCurrentUserPrivacySettings(UUID userId) {
        userService.requireActiveUser(userId);
        return PrivacySettingsResponse.from(requirePrivacySettings(userId));
    }

    @Transactional
    public PrivacySettingsResponse updateCurrentUserPrivacySettings(UUID userId, UpdatePrivacySettingsRequest request) {
        userService.requireActiveUser(userId);
        UserPrivacySettingsEntity settings = requirePrivacySettings(userId);

        boolean changed = false;
        changed |= apply(request.discoverByUsername(), settings.isDiscoverByUsername(), settings::setDiscoverByUsername);
        changed |= apply(request.discoverByQr(), settings.isDiscoverByQr(), settings::setDiscoverByQr);
        changed |= apply(request.discoverByEmail(), settings.isDiscoverByEmail(), settings::setDiscoverByEmail);
        changed |= apply(request.discoverByPhone(), settings.isDiscoverByPhone(), settings::setDiscoverByPhone);
        changed |= apply(request.dmPolicy(), settings.getDmPolicy(), settings::setDmPolicy);
        changed |= apply(request.friendRequestPolicy(), settings.getFriendRequestPolicy(), settings::setFriendRequestPolicy);
        changed |= apply(request.showOnlineStatus(), settings.isShowOnlineStatus(), settings::setShowOnlineStatus);
        changed |= apply(request.showLastSeen(), settings.isShowLastSeen(), settings::setShowLastSeen);

        if (changed) {
            settings.setUpdatedAt(clock.instant());
        }
        return PrivacySettingsResponse.from(settings);
    }

    private UserPrivacySettingsEntity requirePrivacySettings(UUID userId) {
        return userPrivacySettingsRepository.findById(userId)
                .orElseThrow(() -> new IllegalStateException("Active user is missing privacy settings"));
    }

    private <T> boolean apply(T requestedValue, T currentValue, java.util.function.Consumer<T> setter) {
        if (requestedValue == null || requestedValue.equals(currentValue)) {
            return false;
        }
        setter.accept(requestedValue);
        return true;
    }
}
