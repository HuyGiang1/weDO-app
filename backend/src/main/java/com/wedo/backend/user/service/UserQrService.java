package com.wedo.backend.user.service;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.user.dto.PersonalQrResponse;
import com.wedo.backend.user.dto.UserPublicProfileResponse;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserPrivacySettingsRepository;
import com.wedo.backend.user.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Service
@Transactional(readOnly = true)
public class UserQrService {

    private static final Pattern PERSONAL_QR_PATTERN = Pattern.compile(
            "^wedo://user/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})$"
    );

    private final UserService userService;
    private final UserRepository userRepository;
    private final UserPrivacySettingsRepository privacySettingsRepository;

    public UserQrService(
            UserService userService,
            UserRepository userRepository,
            UserPrivacySettingsRepository privacySettingsRepository
    ) {
        this.userService = userService;
        this.userRepository = userRepository;
        this.privacySettingsRepository = privacySettingsRepository;
    }

    public PersonalQrResponse getPersonalQr(UUID userId) {
        userService.requireActiveUser(userId);
        return new PersonalQrResponse(toDeepLink(userId));
    }

    public UserPublicProfileResponse resolveQr(UUID requesterId, String deepLink) {
        userService.requireActiveUser(requesterId);
        UUID targetId = parseTargetId(deepLink);
        UserEntity target = userRepository.findById(targetId)
                .filter(user -> user.getStatus() == UserStatus.ACTIVE)
                .orElseThrow(this::notFound);
        boolean discoverable = privacySettingsRepository.findById(targetId)
                .map(settings -> settings.isDiscoverByQr())
                .orElse(false);
        if (!discoverable) {
            throw notFound();
        }
        return UserPublicProfileResponse.from(target);
    }

    private UUID parseTargetId(String deepLink) {
        Matcher matcher = PERSONAL_QR_PATTERN.matcher(deepLink);
        if (!matcher.matches()) {
            throw notFound();
        }
        try {
            return UUID.fromString(matcher.group(1));
        } catch (IllegalArgumentException exception) {
            throw notFound();
        }
    }

    private String toDeepLink(UUID userId) {
        return "wedo://user/" + userId;
    }

    private BusinessException notFound() {
        return new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);
    }
}
