package com.wedo.backend.user.service;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.user.dto.MyProfileResponse;
import com.wedo.backend.user.dto.UserPublicProfileResponse;
import com.wedo.backend.user.dto.UpdateProfileRequest;
import com.wedo.backend.user.dto.UpdateUsernameRequest;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;
import java.time.Clock;
import java.util.Locale;
import java.util.regex.Pattern;

@Service
@Transactional(readOnly = true)
public class UserService {

    private static final Pattern USERNAME_PATTERN = Pattern.compile("^[a-zA-Z0-9_]{3,30}$");

    private final UserRepository userRepository;
    private final Clock clock;

    public UserService(UserRepository userRepository, Clock clock) {
        this.userRepository = userRepository;
        this.clock = clock;
    }

    public MyProfileResponse getCurrentUser(UUID userId) {
        return MyProfileResponse.from(requireActiveUser(userId));
    }

    public UserPublicProfileResponse getPublicProfile(UUID requesterId, UUID targetUserId) {
        requireActiveUser(requesterId);
        UserEntity target = userRepository.findById(targetUserId)
                .filter(user -> user.getStatus() == UserStatus.ACTIVE)
                .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));
        return UserPublicProfileResponse.from(target);
    }

    @Transactional
    public MyProfileResponse updateProfile(UUID userId, UpdateProfileRequest request) {
        UserEntity user = requireActiveUser(userId);

        if (request.displayName() != null) {
            String displayName = request.displayName().trim();
            if (displayName.isEmpty()) {
                throw new BusinessException(ErrorCode.VALIDATION_FAILED);
            }
            user.setDisplayName(displayName);
        }
        if (request.bio() != null) {
            user.setBio(normalizeClearableTrimmedValue(request.bio()));
        }
        if (request.phone() != null) {
            user.setPhone(normalizeClearableTrimmedValue(request.phone()));
        }
        if (request.avatarStorageKey() != null) {
            user.setAvatarStorageKey(request.avatarStorageKey().isBlank() ? null : request.avatarStorageKey());
        }
        user.setUpdatedAt(clock.instant());
        return MyProfileResponse.from(user);
    }

    @Transactional
    public MyProfileResponse updateUsername(UUID userId, UpdateUsernameRequest request) {
        UserEntity user = requireActiveUser(userId);
        String canonicalUsername = request.username().trim().toLowerCase(Locale.ROOT);
        if (!USERNAME_PATTERN.matcher(canonicalUsername).matches()) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
        if (user.getUsername() != null
                && canonicalUsername.equals(user.getUsername().toLowerCase(Locale.ROOT))) {
            return MyProfileResponse.from(user);
        }
        if (userRepository.existsByUsername(canonicalUsername)) {
            throw new BusinessException(ErrorCode.USERNAME_ALREADY_EXISTS);
        }

        user.setUsername(canonicalUsername);
        user.setUpdatedAt(clock.instant());
        try {
            userRepository.flush();
        } catch (DataIntegrityViolationException exception) {
            if (UsernameUniqueViolationDetector.isUsernameUniqueViolation(exception)) {
                throw new BusinessException(ErrorCode.USERNAME_ALREADY_EXISTS);
            }
            throw exception;
        }
        return MyProfileResponse.from(user);
    }

    public UserEntity requireActiveUser(UUID userId) {
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.AUTH_TOKEN_INVALID));

        UserStatus status = user.getStatus();
        if (status == UserStatus.SUSPENDED) {
            throw new BusinessException(ErrorCode.ACCOUNT_SUSPENDED);
        }
        if (status == UserStatus.DEACTIVATED) {
            throw new BusinessException(ErrorCode.ACCOUNT_DEACTIVATED);
        }
        if (status == UserStatus.PENDING_VERIFICATION) {
            throw new BusinessException(ErrorCode.EMAIL_NOT_VERIFIED);
        }

        return user;
    }

    private String normalizeClearableTrimmedValue(String value) {
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }
}
