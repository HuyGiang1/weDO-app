package com.wedo.backend.media.service;

import org.springframework.core.io.Resource;

public record MediaResource(
        Resource resource,
        String contentType,
        long contentLength
) {}
