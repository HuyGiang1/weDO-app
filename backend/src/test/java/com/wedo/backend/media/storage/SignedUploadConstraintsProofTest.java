package com.wedo.backend.media.storage;

import static org.junit.jupiter.api.Assertions.*;

import java.net.URI;
import java.net.URLDecoder;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.HexFormat;
import java.util.TreeMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.stream.Collectors;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.time.Duration;
import java.util.Map;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Configuration;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.PutObjectPresignRequest;

/** Offline signing gate. Never contacts an endpoint or resolves real credentials. */
class SignedUploadConstraintsProofTest {
    @ParameterizedTest
    @ValueSource(strings = {"image/png", "video/mp4"})
    void realSdkMustCryptographicallyBindBothUploadConstraints(String contentType) throws Exception {
        try (var presigner = S3Presigner.builder()
                .endpointOverride(URI.create("https://storage.invalid"))
                .region(Region.of("auto"))
                .credentialsProvider(StaticCredentialsProvider.create(
                        AwsBasicCredentials.create("synthetic-access", "synthetic-secret")))
                .serviceConfiguration(S3Configuration.builder().pathStyleAccessEnabled(true).build())
                .build()) {
            var signed = presigner.presignPutObject(PutObjectPresignRequest.builder()
                    .signatureDuration(Duration.ofMinutes(10))
                    .putObjectRequest(PutObjectRequest.builder().bucket("synthetic-bucket")
                            .key(contentType.equals("video/mp4") ? "synthetic/object.mp4" : "synthetic/object.png").contentLength(128L)
                            .ifNoneMatch("*").contentType(contentType)
                            .metadata(Map.of("declared-size", "128")).build())
                    .build());
            var names = signed.signedHeaders().keySet();
            // Assert booleans only: assertion failures cannot serialize signed URLs/headers.
            assertTrue(names.contains("content-length"), "CONTENT_LENGTH_NOT_SIGNED");
            assertTrue(names.contains("if-none-match"), "IF_NONE_MATCH_NOT_SIGNED");
            assertTrue(names.contains("content-type"), "CONTENT_TYPE_NOT_SIGNED");
            assertTrue(names.contains("x-amz-meta-declared-size"), "METADATA_NOT_SIGNED");
            var headers = new LinkedHashMap<>(signed.signedHeaders());
            assertTrue(verifies(signed.url().toURI(), headers), "ORIGINAL_SIGNATURE_INVALID");
            for (String name : List.of("content-length", "if-none-match", "content-type")) {
                var missing = new LinkedHashMap<>(headers);
                missing.remove(name);
                assertFalse(verifies(signed.url().toURI(), missing), "MISSING_HEADER_ACCEPTED");
                var modified = new LinkedHashMap<>(headers);
                modified.put(name, List.of(name.equals("content-length") ? "129" : "different"));
                assertFalse(verifies(signed.url().toURI(), modified), "MODIFIED_HEADER_ACCEPTED");
            }
        }
    }

    // Independent SigV4 implementation, deliberately not using SDK signer utilities.
    private static boolean verifies(URI uri, Map<String, List<String>> headers) throws Exception {
        var query = new TreeMap<String, String>();
        for (var pair : uri.getRawQuery().split("&")) {
            var parts = pair.split("=", 2);
            query.put(URLDecoder.decode(parts[0], StandardCharsets.UTF_8),
                    URLDecoder.decode(parts[1], StandardCharsets.UTF_8));
        }
        String signature = query.remove("X-Amz-Signature");
        String signedNames = query.get("X-Amz-SignedHeaders");
        var canonicalHeaders = new StringBuilder();
        for (String name : signedNames.split(";")) {
            if (!headers.containsKey(name)) return false;
            canonicalHeaders.append(name).append(":").append(headers.get(name).stream()
                    .map(value -> value.trim().replaceAll("\\s+", " "))
                    .collect(Collectors.joining(","))).append("\n");
        }
        String canonicalQuery = query.entrySet().stream()
                .map(e -> encode(e.getKey()) + "=" + encode(e.getValue()))
                .collect(Collectors.joining("&"));
        String canonical = "PUT\n" + uri.getRawPath() + "\n" + canonicalQuery + "\n"
                + canonicalHeaders + "\n" + signedNames + "\nUNSIGNED-PAYLOAD";
        String scope = query.get("X-Amz-Credential").split("/", 2)[1];
        String toSign = "AWS4-HMAC-SHA256\n" + query.get("X-Amz-Date") + "\n" + scope + "\n"
                + HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                        .digest(canonical.getBytes(StandardCharsets.UTF_8)));
        byte[] key = "AWS4synthetic-secret".getBytes(StandardCharsets.UTF_8);
        for (String part : scope.split("/")) key = hmac(key, part);
        return MessageDigest.isEqual(HexFormat.of().parseHex(signature), hmac(key, toSign));
    }

    private static String encode(String value) {
        return URLEncoder.encode(value, StandardCharsets.UTF_8)
                .replace("+", "%20").replace("*", "%2A").replace("%7E", "~");
    }

    private static byte[] hmac(byte[] key, String data) throws Exception {
        var mac = Mac.getInstance("HmacSHA256");
        mac.init(new SecretKeySpec(key, "HmacSHA256"));
        return mac.doFinal(data.getBytes(StandardCharsets.UTF_8));
    }
}
