package com.wedo.backend.media.storage;

import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.context.annotation.Profile;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.AwsCredentialsProvider;
import software.amazon.awssdk.auth.credentials.DefaultCredentialsProvider;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.core.exception.SdkException;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3Configuration;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.CreateBucketRequest;
import software.amazon.awssdk.services.s3.model.HeadBucketRequest;
import software.amazon.awssdk.services.s3.model.HeadObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest;
import software.amazon.awssdk.services.s3.presigner.model.PutObjectPresignRequest;

@Component
@Profile("!test")
public class S3ObjectStorageService implements ObjectStorageService {
    private final String bucket;
    private final S3Client client;
    private final S3Presigner presigner;
    private final S3BucketBootstrapper bucketBootstrapper;

    public S3ObjectStorageService(
            @Value("${media.s3.endpoint:}") String endpoint,
            @Value("${media.s3.public-endpoint:}") String publicEndpoint,
            @Value("${media.s3.bucket:wedo-media}") String bucket,
            @Value("${media.s3.region:us-east-1}") String region,
            @Value("${media.s3.access-key:}") String accessKey,
            @Value("${media.s3.secret-key:}") String secretKey,
            @Value("${media.s3.path-style:true}") boolean pathStyle
    ) {
        this.bucket = bucket;
        AwsCredentialsProvider credentials = credentials(accessKey, secretKey);
        S3Configuration s3Configuration = S3Configuration.builder()
                .pathStyleAccessEnabled(pathStyle)
                .build();
        var clientBuilder = S3Client.builder()
                .region(Region.of(region))
                .credentialsProvider(credentials)
                .serviceConfiguration(s3Configuration);
        var presignerBuilder = S3Presigner.builder()
                .region(Region.of(region))
                .credentialsProvider(credentials)
                .serviceConfiguration(s3Configuration);
        if (endpoint != null && !endpoint.isBlank()) {
            clientBuilder.endpointOverride(URI.create(endpoint));
        }
        String signingEndpoint = publicEndpoint == null || publicEndpoint.isBlank() ? endpoint : publicEndpoint;
        if (signingEndpoint != null && !signingEndpoint.isBlank()) {
            presignerBuilder.endpointOverride(URI.create(signingEndpoint));
        }
        this.client = clientBuilder.build();
        this.presigner = presignerBuilder.build();
        this.bucketBootstrapper = new S3BucketBootstrapper(client, bucket);
    }

    private static AwsCredentialsProvider credentials(String accessKey, String secretKey) {
        if (accessKey != null && !accessKey.isBlank() && secretKey != null && !secretKey.isBlank()) {
            return StaticCredentialsProvider.create(AwsBasicCredentials.create(accessKey, secretKey));
        }
        return DefaultCredentialsProvider.create();
    }

    @Override
    public void ensureBucketExists() {
        bucketBootstrapper.ensureExists();
    }

    @Override
    public PresignedObject presignPut(String storageKey, String contentType, long declaredSize, Duration expiry) {
        return presignPut(storageKey, contentType, declaredSize, null, expiry);
    }

    @Override
    public PresignedObject presignPut(String storageKey, String contentType, long declaredSize,
                                     String originalFileName, Duration expiry) {
        Instant expiresAt = Instant.now().plus(expiry);
        var put = PutObjectRequest.builder()
                .bucket(bucket)
                .key(storageKey)
                .contentType(contentType)
                .metadata(originalFileName == null
                        ? Map.of("declared-size", Long.toString(declaredSize))
                        : Map.of("declared-size", Long.toString(declaredSize), "original-file-name",
                                Base64.getUrlEncoder().withoutPadding().encodeToString(originalFileName.getBytes(StandardCharsets.UTF_8))));
        var request = put.build();
        var signed = presigner.presignPutObject(PutObjectPresignRequest.builder()
                .signatureDuration(expiry)
                .putObjectRequest(request)
                .build());
        Map<String, String> headers = originalFileName == null
                ? Map.of("Content-Type", contentType, "x-amz-meta-declared-size", Long.toString(declaredSize))
                : Map.of("Content-Type", contentType, "x-amz-meta-declared-size", Long.toString(declaredSize),
                        "x-amz-meta-original-file-name", Base64.getUrlEncoder().withoutPadding()
                                .encodeToString(originalFileName.getBytes(StandardCharsets.UTF_8)));
        return new PresignedObject(signed.url().toExternalForm(), expiresAt, headers);
    }

    @Override
    public PresignedObject presignGet(String storageKey, Duration expiry) {
        Instant expiresAt = Instant.now().plus(expiry);
        var request = GetObjectRequest.builder().bucket(bucket).key(storageKey).build();
        var signed = presigner.presignGetObject(GetObjectPresignRequest.builder()
                .signatureDuration(expiry)
                .getObjectRequest(request)
                .build());
        return new PresignedObject(signed.url().toExternalForm(), expiresAt, Map.of());
    }

    @Override
    public ObjectMetadata head(String storageKey) {
        try {
            var result = client.headObject(HeadObjectRequest.builder().bucket(bucket).key(storageKey).build());
            return new ObjectMetadata(result.contentType(), result.contentLength(), result.metadata());
        } catch (SdkException exception) {
            throw new ObjectStorageException("Object metadata could not be verified", exception);
        }
    }

    @Override
    public void delete(String storageKey) {
        client.deleteObject(DeleteObjectRequest.builder().bucket(bucket).key(storageKey).build());
    }
}
