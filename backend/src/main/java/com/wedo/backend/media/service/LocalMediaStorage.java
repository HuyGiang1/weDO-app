package com.wedo.backend.media.service;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.FileSystemResource;
import org.springframework.stereotype.Component;

@Component
public class LocalMediaStorage implements MediaStorage {

    private static final Map<String, String> ALLOWED_MIME_TYPES = Map.of(
            "image/jpeg", ".jpg",
            "image/png", ".png",
            "image/webp", ".webp"
    );

    private final Path rootPath;

    public LocalMediaStorage(@Value("${media.local.base-dir:.local-media}") String baseDir) {
        this.rootPath = Paths.get(baseDir).toAbsolutePath().normalize();
    }

    @Override
    public MediaUploadResult storeAvatar(byte[] bytes, String contentType, String originalFilename) {
        if (contentType == null || !ALLOWED_MIME_TYPES.containsKey(contentType.toLowerCase())) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
        String ext = ALLOWED_MIME_TYPES.get(contentType.toLowerCase());
        String filename = UUID.randomUUID() + ext;
        String storageKey = "avatars/" + filename;

        Path target = rootPath.resolve("avatars").resolve(filename).normalize();
        if (!target.startsWith(rootPath)) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }

        try {
            Files.createDirectories(target.getParent());
            Files.write(target, bytes);
        } catch (IOException e) {
            throw new BusinessException(ErrorCode.INTERNAL_SERVER_ERROR);
        }

        return new MediaUploadResult(storageKey, contentType, bytes.length, "/api/v1/media/" + storageKey);
    }

    @Override
    public Optional<MediaResource> load(String storageKey) {
        if (storageKey == null || storageKey.isBlank() || storageKey.contains("..")) {
            return Optional.empty();
        }

        Path target = rootPath.resolve(storageKey).normalize();
        if (!target.startsWith(rootPath) || !Files.exists(target) || !Files.isRegularFile(target)) {
            return Optional.empty();
        }

        try {
            long size = Files.size(target);
            String contentType = Files.probeContentType(target);
            if (contentType == null) {
                String lower = target.toString().toLowerCase();
                if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) contentType = "image/jpeg";
                else if (lower.endsWith(".png")) contentType = "image/png";
                else if (lower.endsWith(".webp")) contentType = "image/webp";
                else contentType = "application/octet-stream";
            }
            return Optional.of(new MediaResource(new FileSystemResource(target), contentType, size));
        } catch (IOException e) {
            return Optional.empty();
        }
    }
}
