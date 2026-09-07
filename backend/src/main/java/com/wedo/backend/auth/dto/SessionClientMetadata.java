package com.wedo.backend.auth.dto;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;

public record SessionClientMetadata(
        String deviceName,
        String ipAddress
) {

    public static SessionClientMetadata of(String rawDeviceName, String rawIpAddress) {
        String normalizedDeviceName = normalizeDeviceName(rawDeviceName);
        String normalizedIp = normalizeIpAddress(rawIpAddress);
        return new SessionClientMetadata(normalizedDeviceName, normalizedIp);
    }

    public static SessionClientMetadata empty() {
        return new SessionClientMetadata(null, null);
    }

    private static String normalizeDeviceName(String raw) {
        if (raw == null) {
            return null;
        }
        String trimmed = raw.trim();
        if (trimmed.isEmpty()) {
            return null;
        }
        if (trimmed.length() > 100) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
        return trimmed;
    }

    private static String normalizeIpAddress(String raw) {
        if (raw == null) {
            return null;
        }
        String trimmed = raw.trim();
        if (trimmed.isEmpty()) {
            return null;
        }
        if (trimmed.length() <= 45) {
            return trimmed;
        }
        return null;
    }
}
