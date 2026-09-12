package com.wedo.backend.user.service;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.user.dto.MyProfileResponse;
import com.wedo.backend.user.dto.UpdateProfileRequest;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;
import java.time.Clock;

@Service
@Transactional(readOnly = true)
public class UserService {

    private final UserRepository userRepository;
    private final Clock clock;

    public UserService(UserRepository userRepository, Clock clock) {
        this.userRepository = userRepository;
        this.clock = clock;
    }

    public MyProfileResponse getCurrentUser(UUID userId) {
        return MyProfileResponse.from(requireActiveUser(userId));
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

    private UserEntity requireActiveUser(UUID userId) {
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
