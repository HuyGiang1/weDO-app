package com.wedo.backend.media.storage;

import static org.junit.jupiter.api.Assertions.*;
import java.util.Map;
import java.util.List;
import java.util.LinkedHashMap;
import java.time.Duration;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.mock.env.MockEnvironment;

class StagingSignedUploadTest {
    private Map<String, List<String>> headers() {
        return new LinkedHashMap<>(Map.of("host", List.of("storage.invalid"),
                "content-length", List.of("128"), "if-none-match", List.of("*"),
                "content-type", List.of("image/png"), "x-amz-meta-declared-size", List.of("128")));
    }
    @Test void stagingReturnsSdkSignedHeadersWithoutHostOrCredentials() {
        var env = new MockEnvironment();
        env.setActiveProfiles("local", "staging");
        var storage = new S3ObjectStorageService("https://storage.invalid", "", "synthetic-bucket",
                "auto", "synthetic-access", "synthetic-secret", true, env);
        var result = storage.presignPut("synthetic/file.png", "image/png", 128, "synthetic.png", Duration.ofMinutes(10));
        assertEquals("128", result.requiredHeaders().get("content-length"));
        assertEquals("*", result.requiredHeaders().get("if-none-match"));
        assertTrue(result.requiredHeaders().containsKey("x-amz-meta-original-file-name"));
        assertFalse(result.requiredHeaders().containsKey("host"));
        assertFalse(result.requiredHeaders().containsKey("authorization"));
        // Independently proven real SDK signature; returned headers retain all signed non-host values.
        assertTrue(result.url().contains("content-length%3B"));
        assertTrue(result.url().contains("if-none-match%3B"));
        String query = java.net.URI.create(result.url()).getRawQuery();
        String signedNames = java.util.Arrays.stream(query.split("&"))
                .filter(pair -> pair.startsWith("X-Amz-SignedHeaders="))
                .map(pair -> java.net.URLDecoder.decode(pair.split("=", 2)[1], java.nio.charset.StandardCharsets.UTF_8))
                .findFirst().orElseThrow();
        var expectedNames = new java.util.HashSet<>(java.util.Arrays.asList(signedNames.split(";")));
        expectedNames.remove("host");
        assertTrue(expectedNames.equals(result.requiredHeaders().keySet()), "REQUIRED_HEADERS_MUST_MATCH_SIGNATURE");
        assertThrows(ObjectStorageException.class, () -> storage.presignPut("synthetic/file", "application/octet-stream", 128, Duration.ofMinutes(10)));
    }
    @Test void stagingMp4RetainsExactLengthAndConditionalWriteSignature() {
        var env = new MockEnvironment();
        env.setActiveProfiles("staging");
        var storage = new S3ObjectStorageService("https://storage.invalid", "", "synthetic-bucket",
                "auto", "synthetic-access", "synthetic-secret", true, env);
        var result = storage.presignPut("synthetic/video.mp4", "video/mp4", 16645,
                "synthetic.mp4", Duration.ofMinutes(10));
        assertEquals("16645", result.requiredHeaders().get("content-length"));
        assertEquals("*", result.requiredHeaders().get("if-none-match"));
        assertEquals("video/mp4", result.requiredHeaders().get("content-type"));
        assertEquals("16645", result.requiredHeaders().get("x-amz-meta-declared-size"));
        String names = java.util.Arrays.stream(java.net.URI.create(result.url()).getRawQuery().split("&"))
                .filter(pair -> pair.startsWith("X-Amz-SignedHeaders="))
                .map(pair -> java.net.URLDecoder.decode(pair.split("=", 2)[1], java.nio.charset.StandardCharsets.UTF_8))
                .findFirst().orElseThrow();
        var expected = new java.util.HashSet<>(java.util.Arrays.asList(names.split(";")));
        assertTrue(expected.containsAll(List.of("content-length", "if-none-match", "content-type")));
        expected.remove("host");
        assertEquals(expected, result.requiredHeaders().keySet());
        assertFalse(result.requiredHeaders().containsKey("authorization"));
    }
    @Test void nonStagingPreservesExistingTransportContract() {
        var storage = new S3ObjectStorageService("https://storage.invalid", "", "synthetic-bucket",
                "auto", "synthetic-access", "synthetic-secret", true);
        var result = storage.presignPut("synthetic/video", "video/mp4", 128, Duration.ofMinutes(10));
        assertEquals(Map.of("Content-Type", "video/mp4", "x-amz-meta-declared-size", "128"), result.requiredHeaders());
        assertFalse(result.url().contains("if-none-match"));
    }
    @ParameterizedTest @ValueSource(strings={"content-length", "if-none-match", "content-type", "host", "x-amz-meta-declared-size"})
    void missingSignedRequirementFailsClosed(String name) {
        var headers = headers(); headers.remove(name);
        var failure = assertThrows(ObjectStorageException.class, () -> S3ObjectStorageService.constrainedHeaders(headers, 128));
        assertEquals("Staging upload constraints unavailable", failure.getMessage());
        assertNull(failure.getCause());
    }
    @ParameterizedTest @ValueSource(strings={"0", "127", "129", "128,128", "128\r\n"})
    void invalidLengthFailsClosed(String value) {
        var headers = headers(); headers.put("content-length", List.of(value));
        assertThrows(ObjectStorageException.class, () -> S3ObjectStorageService.constrainedHeaders(headers, 128));
    }
    @Test void modifiedConditionalAndDuplicateHeadersFailClosed() {
        var headers = headers(); headers.put("if-none-match", List.of("different"));
        assertThrows(ObjectStorageException.class, () -> S3ObjectStorageService.constrainedHeaders(headers, 128));
        headers.put("if-none-match", List.of("*")); headers.put("Content-Length", List.of("128"));
        assertThrows(ObjectStorageException.class, () -> S3ObjectStorageService.constrainedHeaders(headers, 128));
        headers.remove("Content-Length"); headers.put("content-length", List.of("128", "128"));
        assertThrows(ObjectStorageException.class, () -> S3ObjectStorageService.constrainedHeaders(headers, 128));
    }
}
