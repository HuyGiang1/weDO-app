package com.wedo.backend.media.storage;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

@Component
public class StorageBucketBootstrap implements ApplicationRunner {
    private final ObjectStorageService storage;
    private final boolean enabled;

    public StorageBucketBootstrap(
            ObjectStorageService storage,
            @Value("${media.s3.bootstrap-bucket:false}") boolean enabled
    ) {
        this.storage = storage;
        this.enabled = enabled;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (!enabled) return;
        try {
            storage.ensureBucketExists();
        } catch (RuntimeException exception) {
            throw new IllegalStateException(
                    "Media bucket bootstrap is enabled but configured storage is unavailable", exception);
        }
    }
}
