package com.wedo.backend.media.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

public record PresignUploadRequest(
        @NotNull UploadCategory category,
        @NotBlank @Size(max = 255) String fileName,
        @NotBlank @Size(max = 100) String contentType,
        @Positive long fileSize,
        String contextId
) {}
