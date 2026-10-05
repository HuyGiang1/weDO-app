package com.wedo.backend.media.storage;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import org.junit.jupiter.api.Test;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.HeadBucketRequest;
import software.amazon.awssdk.services.s3.model.HeadBucketResponse;
import software.amazon.awssdk.services.s3.model.S3Exception;

class S3BucketBootstrapperTest {
    private final S3Client client = mock(S3Client.class);
    private final S3BucketBootstrapper bootstrapper = new S3BucketBootstrapper(client, "wedo-media");

    @Test
    void existingBucketIsLeftUntouched() {
        when(client.headBucket(any(HeadBucketRequest.class))).thenReturn(HeadBucketResponse.builder().build());

        bootstrapper.ensureExists();

        verify(client, never()).createBucket(any(software.amazon.awssdk.services.s3.model.CreateBucketRequest.class));
    }

    @Test
    void missingBucketIsCreated() {
        when(client.headBucket(any(HeadBucketRequest.class)))
                .thenThrow(s3Exception(404, "NoSuchBucket"));

        bootstrapper.ensureExists();

        verify(client).createBucket(any(software.amazon.awssdk.services.s3.model.CreateBucketRequest.class));
    }

    @Test
    void inaccessibleBucketFailsWithoutAttemptingCreation() {
        when(client.headBucket(any(HeadBucketRequest.class)))
                .thenThrow(s3Exception(403, "AccessDenied"));

        assertThrows(ObjectStorageException.class, bootstrapper::ensureExists);

        verify(client, never()).createBucket(any(software.amazon.awssdk.services.s3.model.CreateBucketRequest.class));
    }

    @Test
    void concurrentCreationIsAcceptedOnlyAfterBucketCanBeHeaded() {
        when(client.headBucket(any(HeadBucketRequest.class)))
                .thenThrow(s3Exception(404, "NoSuchBucket"))
                .thenReturn(HeadBucketResponse.builder().build());
        doThrow(s3Exception(409, "BucketAlreadyOwnedByYou"))
                .when(client).createBucket(any(software.amazon.awssdk.services.s3.model.CreateBucketRequest.class));

        bootstrapper.ensureExists();

        verify(client, org.mockito.Mockito.times(2)).headBucket(any(HeadBucketRequest.class));
    }

    private static S3Exception s3Exception(int status, String code) {
        return (S3Exception) S3Exception.builder()
                .statusCode(status)
                .message(code)
                .build();
    }
}
