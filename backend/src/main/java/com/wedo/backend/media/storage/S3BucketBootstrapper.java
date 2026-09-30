package com.wedo.backend.media.storage;

import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.CreateBucketRequest;
import software.amazon.awssdk.services.s3.model.HeadBucketRequest;
import software.amazon.awssdk.services.s3.model.S3Exception;

final class S3BucketBootstrapper {
    private final S3Client client;
    private final String bucket;

    S3BucketBootstrapper(S3Client client, String bucket) {
        this.client = client;
        this.bucket = bucket;
    }

    void ensureExists() {
        try {
            client.headBucket(HeadBucketRequest.builder().bucket(bucket).build());
            return;
        } catch (S3Exception exception) {
            if (!isMissing(exception)) throw inaccessible(exception);
        } catch (RuntimeException exception) {
            throw inaccessible(exception);
        }

        try {
            client.createBucket(CreateBucketRequest.builder().bucket(bucket).build());
        } catch (S3Exception exception) {
            if (exception.statusCode() != 409) throw inaccessible(exception);
            try {
                client.headBucket(HeadBucketRequest.builder().bucket(bucket).build());
            } catch (RuntimeException raceFailure) {
                throw inaccessible(raceFailure);
            }
        } catch (RuntimeException exception) {
            throw inaccessible(exception);
        }
    }

    private boolean isMissing(S3Exception exception) {
        String code = exception.awsErrorDetails() == null
                ? null : exception.awsErrorDetails().errorCode();
        return exception.statusCode() == 404 || "NoSuchBucket".equals(code) || "NotFound".equals(code);
    }

    private ObjectStorageException inaccessible(RuntimeException cause) {
        return new ObjectStorageException("Configured media bucket is inaccessible or could not be created", cause);
    }
}
