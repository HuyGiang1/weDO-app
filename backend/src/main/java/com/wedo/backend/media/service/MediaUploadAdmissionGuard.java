package com.wedo.backend.media.service;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import java.util.HashSet;
import java.util.Set;
import java.util.UUID;
import org.springframework.core.env.Environment;
import org.springframework.core.env.Profiles;
import org.springframework.stereotype.Component;

/** Staging upload admission only. This is neither a quota nor a storage spending cap. */
@Component
public class MediaUploadAdmissionGuard {
    private static final int MAX_USERS = 10;
    private final boolean staging;
    private final boolean open;
    private final Set<UUID> allowed;

    public MediaUploadAdmissionGuard(Environment environment) {
        staging = environment.acceptsProfiles(Profiles.of("staging"));
        if (!staging) {
            open = false;
            allowed = Set.of();
            return; // Ignore staging settings completely in local/test/teammate/other profiles.
        }
        String enabled = environment.getProperty("wedo.staging.media-upload.enabled", "false");
        String configured = environment.getProperty("wedo.staging.media-upload.allowed-user-ids", "");
        Set<UUID> parsed = new HashSet<>();
        boolean valid = "true".equals(enabled) || "false".equals(enabled);
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
        if (staging && (category == com.wedo.backend.media.dto.UploadCategory.MOMENT_VIDEO
                || contentType == null || !contentType.startsWith("image/"))) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
    }

    public void requireAllowed(UUID userId) {
        if (staging && (!open || userId == null || !allowed.contains(userId))) {
            // Never disclose allowlist entries or malformed configuration in HTTP errors/logs.
            throw new BusinessException(ErrorCode.ACCESS_DENIED);
        }
    }
}
