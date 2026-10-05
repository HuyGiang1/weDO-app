package com.wedo.backend.media.dto;

import java.time.Instant;
import java.util.Map;

public record PresignUploadResponse(
        String storageKey,
        String uploadUrl,
        Instant expiresAt,
        Map<String, String> requiredHeaders
) {}
