package com.wedo.backend.media.storage;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import org.junit.jupiter.api.Test;
import org.springframework.boot.DefaultApplicationArguments;

class StorageBucketBootstrapTest {
    private final ObjectStorageService storage = mock(ObjectStorageService.class);
    private final DefaultApplicationArguments arguments = new DefaultApplicationArguments();

    @Test
    void disabledBootstrapDoesNotCallStorage() {
        new StorageBucketBootstrap(storage, false).run(arguments);

        verify(storage, never()).ensureBucketExists();
    }

    @Test
    void enabledBootstrapEnsuresBucketExists() {
        new StorageBucketBootstrap(storage, true).run(arguments);

        verify(storage).ensureBucketExists();
    }

    @Test
    void enabledBootstrapFailsStartupWithSafeMessageWhenStorageIsUnavailable() {
        org.mockito.Mockito.doThrow(new ObjectStorageException("unavailable", null))
                .when(storage).ensureBucketExists();

        IllegalStateException failure = assertThrows(IllegalStateException.class,
                () -> new StorageBucketBootstrap(storage, true).run(arguments));

        org.junit.jupiter.api.Assertions.assertEquals(
                "Media bucket bootstrap is enabled but configured storage is unavailable", failure.getMessage());
    }
}
