package com.wedo.backend.media.storage;

import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

@Component
@Profile("test")
public class InMemoryObjectStorageService implements ObjectStorageService {
    private final Map<String, ObjectMetadata> objects = new ConcurrentHashMap<>();

    @Override
    public void ensureBucketExists() {
        // The in-memory test store is available as soon as the test context is created.
    }

    @Override
    public PresignedObject presignPut(String storageKey, String contentType, long size, Duration expiry) {
        return new PresignedObject("http://storage.test/put", Instant.now().plus(expiry),
                Map.of("Content-Type", contentType, "x-amz-meta-declared-size", Long.toString(size)));
    }

    @Override
    public PresignedObject presignGet(String storageKey, Duration expiry) {
        return new PresignedObject("http://storage.test/get", Instant.now().plus(expiry), Map.of());
    }

    @Override
    public ObjectMetadata head(String storageKey) {
        ObjectMetadata metadata = objects.get(storageKey);
        if (metadata == null) throw new ObjectStorageException("Object not found", null);
        return metadata;
    }

    @Override
    public void delete(String storageKey) {
        objects.remove(storageKey);
    }

    public void putForTest(String key, String contentType, long size) {
        objects.put(key, new ObjectMetadata(contentType, size, Map.of("declared-size", Long.toString(size))));
    }

    public boolean containsForTest(String key) {
        return objects.containsKey(key);
    }
}
