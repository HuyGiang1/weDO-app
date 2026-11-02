package com.wedo.backend.media.service;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import java.util.HashSet;
import java.util.Set;
import java.util.UUID;
import org.springframework.core.env.Environment;
import org.springframework.core.env.Profiles;
import org.springframework.stereotype.Component;

/** Staging-only admission and conservative reservation policy; not a provider spending cap. */
@Component
public class MediaUploadAdmissionGuard {
    private static final int MAX_USERS = 3;
    private final boolean staging;
    private final boolean open;
    private final Set<UUID> allowed;
    private final boolean video;
    private final long imageBytes, videoBytes, quotaBytes, windowSeconds;
    private final int requests;
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private StagingMediaReservationService reservations;

    public MediaUploadAdmissionGuard(Environment environment) {
        staging = environment.acceptsProfiles(Profiles.of("staging"));
        imageBytes = limit(environment, "max-image-bytes", 5L * 1024 * 1024, 5L * 1024 * 1024);
        videoBytes = limit(environment, "max-video-bytes", 20L * 1024 * 1024, 20L * 1024 * 1024);
        quotaBytes = limit(environment, "quota-bytes", 150L * 1024 * 1024, 150L * 1024 * 1024);
        requests = (int) limit(environment, "max-requests", 5, 5);
        long configuredWindow = limit(environment, "window-seconds", 600, 86400);
        windowSeconds = configuredWindow >= 600 ? configuredWindow : -1;
        String videoSetting = environment.getProperty("wedo.staging.media-upload.video-enabled", "false");
        video = "true".equals(videoSetting);
        if (!staging) {
            open = false;
            allowed = Set.of();
            return; // Ignore staging settings completely in local/test/teammate/other profiles.
        }
        String enabled = environment.getProperty("wedo.staging.media-upload.enabled", "false");
        String configured = environment.getProperty("wedo.staging.media-upload.allowed-user-ids", "");
        Set<UUID> parsed = new HashSet<>();
        boolean valid = ("true".equals(enabled) || "false".equals(enabled))
                && ("true".equals(videoSetting) || "false".equals(videoSetting))
                && imageBytes > 0 && videoBytes > 0 && quotaBytes > 0 && requests > 0 && windowSeconds > 0;
        if (configured.isBlank()) valid = false;
        else {
            String[] entries = configured.split(",", -1);
            if (entries.length > MAX_USERS) valid = false;
            else {
                for (String entry : entries) {
                    String text = entry.trim();
                    try {
                        UUID user = UUID.fromString(text);
                        if (!user.toString().equalsIgnoreCase(text) || !parsed.add(user)) valid = false;
                    } catch (IllegalArgumentException invalid) {
                        valid = false;
                    }
                }
            }
        }
        open = valid && "true".equals(enabled);
        allowed = valid ? Set.copyOf(parsed) : Set.of();
    }

    public void requireImageUpload(com.wedo.backend.media.dto.UploadCategory category, String contentType) {
        boolean isVideo = category == com.wedo.backend.media.dto.UploadCategory.MOMENT_VIDEO;
        if (staging && (contentType == null || (isVideo
                ? !video || !"video/mp4".equals(contentType)
                : !java.util.Set.of("image/png", "image/jpeg", "image/webp").contains(contentType)))) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
    }

    public void requireSize(com.wedo.backend.media.dto.UploadCategory category, long bytes) {
        if (staging && (bytes <= 0 || bytes > (category == com.wedo.backend.media.dto.UploadCategory.MOMENT_VIDEO ? videoBytes : imageBytes))) {
            throw new BusinessException(ErrorCode.STAGING_MEDIA_FILE_TOO_LARGE);
        }
    }

    public void reserve(UUID userId, String key, long bytes) {
        if (!staging) return;
        requireAllowed(userId);
        if (reservations == null) throw new BusinessException(ErrorCode.INTERNAL_SERVER_ERROR);
        reservations.reserve(userId, key, bytes, quotaBytes, requests, windowSeconds);
    }

    public void requireLegacyUpload(UUID userId) {
        requireAllowed(userId);
        if (staging) throw new BusinessException(ErrorCode.STAGING_MEDIA_PRESIGN_REQUIRED);
    }

    private static long limit(Environment env, String name, long fallback, long ceiling) {
        try {
            long value = Long.parseLong(env.getProperty("wedo.staging.media-upload." + name, Long.toString(fallback)));
            return value > 0 && value <= ceiling ? value : -1;
        } catch (NumberFormatException invalid) { return -1; }
    }

    public void requireAllowed(UUID userId) {
        if (staging && !open) throw new BusinessException(ErrorCode.STAGING_MEDIA_UPLOAD_DISABLED);
        if (staging && (userId == null || !allowed.contains(userId))) {
            // Never disclose allowlist entries or malformed configuration in HTTP errors/logs.
            throw new BusinessException(ErrorCode.STAGING_MEDIA_UPLOAD_NOT_ALLOWED);
        }
    }
}
