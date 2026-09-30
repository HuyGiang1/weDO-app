package com.wedo.backend.media.storage;

import java.time.Duration;
import java.time.Instant;
import java.util.Map;

public interface ObjectStorageService {
    void ensureBucketExists();
    PresignedObject presignPut(String storageKey, String contentType, long declaredSize, Duration expiry);
    default PresignedObject presignPut(String storageKey, String contentType, long declaredSize,
                                      String originalFileName, Duration expiry) {
        return presignPut(storageKey, contentType, declaredSize, expiry);
    }
    PresignedObject presignGet(String storageKey, Duration expiry);
    ObjectMetadata head(String storageKey);
    void delete(String storageKey);

    record PresignedObject(String url, Instant expiresAt, Map<String, String> requiredHeaders) {}
    record ObjectMetadata(String contentType, long size, java.util.Map<String, String> metadata) {}
}
