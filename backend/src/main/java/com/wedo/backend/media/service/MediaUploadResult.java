package com.wedo.backend.media.service;

public record MediaUploadResult(
        String storageKey,
        String contentType,
        long size,
        String url
) {}
