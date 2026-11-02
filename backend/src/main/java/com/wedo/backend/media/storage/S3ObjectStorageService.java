package com.wedo.backend.media.storage;

import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.LinkedHashMap;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.env.Environment;
import org.springframework.core.env.Profiles;
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
    private final boolean staging;
    private final S3Client client;
    private final S3Presigner presigner;
    private final S3BucketBootstrapper bucketBootstrapper;

    // Preserve direct non-Spring callers and their existing non-staging behavior.
    public S3ObjectStorageService(String endpoint, String publicEndpoint, String bucket,
                                  String region, String accessKey, String secretKey, boolean pathStyle) {
        this(endpoint, publicEndpoint, bucket, region, accessKey, secretKey, pathStyle, null);
    }

    @Autowired
    public S3ObjectStorageService(
            @Value("${media.s3.endpoint:}") String endpoint,
            @Value("${media.s3.public-endpoint:}") String publicEndpoint,
            @Value("${media.s3.bucket:wedo-media}") String bucket,
            @Value("${media.s3.region:us-east-1}") String region,
            @Value("${media.s3.access-key:}") String accessKey,
            @Value("${media.s3.secret-key:}") String secretKey,
            @Value("${media.s3.path-style:true}") boolean pathStyle,
            Environment environment
    ) {
        this.bucket = bucket;
        this.staging = environment != null && environment.acceptsProfiles(Profiles.of("staging"));
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
        if (staging) {
            if (declaredSize <= 0 || contentType == null || !contentType.startsWith("image/")) {
                throw constraintsUnavailable();
            }
            put.contentLength(declaredSize).ifNoneMatch("*");
        }
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
        if (staging) headers = constrainedHeaders(signed.signedHeaders(), declaredSize);
        return new PresignedObject(signed.url().toExternalForm(), expiresAt, headers);
    }

    /** Return only actual signed headers; Host is supplied by the HTTP transport. */
    static Map<String, String> constrainedHeaders(Map<String, List<String>> signed, long size) {
        var result = new LinkedHashMap<String, String>();
        for (var entry : signed.entrySet()) {
            String name = entry.getKey().toLowerCase(java.util.Locale.ROOT);
            var values = entry.getValue();
            if (values.size() != 1 || values.getFirst().contains("\r") || values.getFirst().contains("\n")
                    || result.putIfAbsent(name, values.getFirst()) != null
                    || name.equals("authorization")) throw constraintsUnavailable();
        }
        if (size <= 0 || !Long.toString(size).equals(result.get("content-length"))
                || !"*".equals(result.get("if-none-match"))
                || !result.containsKey("content-type") || !result.containsKey("host")
                || !Long.toString(size).equals(result.get("x-amz-meta-declared-size"))) {
            throw constraintsUnavailable();
        }
        result.remove("host");
        return Map.copyOf(result);
    }

    private static ObjectStorageException constraintsUnavailable() {
        // No SDK request, signed URL or exception cause enters diagnostic output.
        return new ObjectStorageException("Staging upload constraints unavailable", null);
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
