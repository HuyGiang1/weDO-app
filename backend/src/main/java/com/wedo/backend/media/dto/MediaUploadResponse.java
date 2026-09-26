package com.wedo.backend.media.dto;

public record MediaUploadResponse(
        String storageKey,
        String contentType,
        long size,
        String url
) {}
