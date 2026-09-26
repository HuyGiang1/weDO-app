package com.wedo.backend.media.service;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.user.service.UserService;
import java.io.IOException;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

@Service
public class MediaService {

    private static final long MAX_AVATAR_SIZE = 5 * 1024 * 1024; // 5MB

    private final MediaStorage mediaStorage;
    private final UserService userService;

    public MediaService(MediaStorage mediaStorage, UserService userService) {
        this.mediaStorage = mediaStorage;
        this.userService = userService;
    }

    public MediaUploadResult uploadAvatar(UUID callerUserId, MultipartFile file) {
        userService.requireActiveUser(callerUserId);
        if (file == null || file.isEmpty()) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
        if (file.getSize() > MAX_AVATAR_SIZE) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
        try {
            return mediaStorage.storeAvatar(file.getBytes(), file.getContentType(), file.getOriginalFilename());
        } catch (IOException e) {
            throw new BusinessException(ErrorCode.INTERNAL_SERVER_ERROR);
        }
    }

    public MediaResource loadMedia(String category, String filename) {
        if (category == null || filename == null || category.isBlank() || filename.isBlank()) {
            throw new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);
        }
        String storageKey = category + "/" + filename;
        return mediaStorage.load(storageKey)
                .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));
    }
}
