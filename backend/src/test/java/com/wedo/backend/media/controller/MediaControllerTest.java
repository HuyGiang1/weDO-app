package com.wedo.backend.media.controller;

import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.security.jwt.JwtService;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.time.Instant;
import java.util.UUID;

import static org.hamcrest.Matchers.startsWith;
import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
class MediaControllerTest extends AbstractPostgresIntegrationTest {

    @Autowired private MockMvc mockMvc;
    @Autowired private JwtService jwtService;
    @Autowired private UserRepository userRepository;

    private UUID activeUserId;
    private UUID suspendedUserId;

    @BeforeEach
    void setUp() {
        activeUserId = createUser(UserStatus.ACTIVE);
        suspendedUserId = createUser(UserStatus.SUSPENDED);
    }

    private UUID createUser(UserStatus status) {
        UUID id = UUID.randomUUID();
        UserEntity user = new UserEntity(
                id,
                "media_user_" + id.toString().substring(0, 8) + "@example.com",
                "media_" + id.toString().substring(0, 8),
                "Media User",
                status,
                Instant.now(),
                Instant.now()
        );
        userRepository.save(user);
        return id;
    }

    private String bearer(UUID userId) {
        return "Bearer " + jwtService.generateAccessToken(userId);
    }

    @Test
    void uploadAvatar_validJpeg_returnsCreatedAndAllowsPublicGet() throws Exception {
        byte[] content = new byte[]{ (byte) 0xFF, (byte) 0xD8, (byte) 0xFF, (byte) 0xE0, 0x01, 0x02 };
        MockMultipartFile file = new MockMultipartFile("file", "test.jpg", "image/jpeg", content);

        MvcResult result = mockMvc.perform(multipart("/api/v1/media/avatar")
                        .file(file)
                        .header("Authorization", bearer(activeUserId)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.storageKey", startsWith("avatars/")))
                .andExpect(jsonPath("$.contentType").value("image/jpeg"))
                .andExpect(jsonPath("$.size").value(content.length))
                .andReturn();

        String responseBody = result.getResponse().getContentAsString();
        String storageKey = com.jayway.jsonpath.JsonPath.read(responseBody, "$.storageKey");
        assertNotNull(storageKey);

        mockMvc.perform(get("/api/v1/media/" + storageKey))
                .andExpect(status().isOk())
                .andExpect(res -> {
                    assertEqualsMediaType("image/jpeg", res.getResponse().getContentType());
                    assertArrayEquals(content, res.getResponse().getContentAsByteArray());
                });
    }

    @Test
    void uploadAvatar_validPngAndWebp_succeeds() throws Exception {
        byte[] pngContent = new byte[]{ (byte) 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A };
        MockMultipartFile pngFile = new MockMultipartFile("file", "test.png", "image/png", pngContent);

        mockMvc.perform(multipart("/api/v1/media/avatar")
                        .file(pngFile)
                        .header("Authorization", bearer(activeUserId)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.contentType").value("image/png"));

        byte[] webpContent = "RIFF....WEBP".getBytes();
        MockMultipartFile webpFile = new MockMultipartFile("file", "test.webp", "image/webp", webpContent);

        mockMvc.perform(multipart("/api/v1/media/avatar")
                        .file(webpFile)
                        .header("Authorization", bearer(activeUserId)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.contentType").value("image/webp"));
    }

    @Test
    void uploadAvatar_unsupportedMime_rejectedWithBadRequest() throws Exception {
        MockMultipartFile textFile = new MockMultipartFile("file", "test.txt", "text/plain", "hello".getBytes());

        mockMvc.perform(multipart("/api/v1/media/avatar")
                        .file(textFile)
                        .header("Authorization", bearer(activeUserId)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));

        MockMultipartFile gifFile = new MockMultipartFile("file", "test.gif", "image/gif", "GIF89a".getBytes());

        mockMvc.perform(multipart("/api/v1/media/avatar")
                        .file(gifFile)
                        .header("Authorization", bearer(activeUserId)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
    }

    @Test
    void uploadAvatar_oversizedFile_rejectedWithBadRequest() throws Exception {
        byte[] oversized = new byte[6 * 1024 * 1024]; // 6MB > 5MB limit
        MockMultipartFile largeFile = new MockMultipartFile("file", "large.jpg", "image/jpeg", oversized);

        mockMvc.perform(multipart("/api/v1/media/avatar")
                        .file(largeFile)
                        .header("Authorization", bearer(activeUserId)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
    }

    @Test
    void uploadAvatar_pathTraversalMaliciousFilename_storedSafely() throws Exception {
        byte[] content = new byte[]{ (byte) 0xFF, (byte) 0xD8, 0x01, 0x02 };
        MockMultipartFile maliciousFile = new MockMultipartFile("file", "../../../etc/passwd", "image/jpeg", content);

        MvcResult result = mockMvc.perform(multipart("/api/v1/media/avatar")
                        .file(maliciousFile)
                        .header("Authorization", bearer(activeUserId)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.storageKey", startsWith("avatars/")))
                .andReturn();

        String responseBody = result.getResponse().getContentAsString();
        String storageKey = com.jayway.jsonpath.JsonPath.read(responseBody, "$.storageKey");

        // The stored key is an opaque UUID, not the path traversal filename
        org.junit.jupiter.api.Assertions.assertFalse(storageKey.contains("passwd"));
        org.junit.jupiter.api.Assertions.assertFalse(storageKey.contains(".."));
    }

    @Test
    void uploadAvatar_anonymousUser_denied() throws Exception {
        MockMultipartFile file = new MockMultipartFile("file", "test.jpg", "image/jpeg", new byte[]{ 0x01 });

        mockMvc.perform(multipart("/api/v1/media/avatar").file(file))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void uploadAvatar_inactiveUser_denied() throws Exception {
        MockMultipartFile file = new MockMultipartFile("file", "test.jpg", "image/jpeg", new byte[]{ 0x01 });

        mockMvc.perform(multipart("/api/v1/media/avatar")
                        .file(file)
                        .header("Authorization", bearer(suspendedUserId)))
                .andExpect(status().isForbidden());
    }

    private void assertEqualsMediaType(String expected, String actual) {
        if (actual == null) throw new AssertionError("Content type was null");
        MediaType expectedType = MediaType.parseMediaType(expected);
        MediaType actualType = MediaType.parseMediaType(actual);
        org.junit.jupiter.api.Assertions.assertTrue(expectedType.isCompatibleWith(actualType));
    }
}
