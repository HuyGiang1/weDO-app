package com.wedo.backend.media.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.group.service.GroupPermissionService;
import com.wedo.backend.media.dto.PresignUploadRequest;
import com.wedo.backend.media.dto.UploadCategory;
import com.wedo.backend.media.storage.ObjectStorageService;
import com.wedo.backend.user.service.UserService;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class UploadServiceTest {
    @Mock private ObjectStorageService storage;
    @Mock private UserService userService;
    @Mock private GroupPermissionService groupPermissionService;
    private UploadService service;

    @BeforeEach
    void setUp() {
        service = new UploadService(storage, userService, groupPermissionService);
    }

    @Test
    void avatarPresignUsesAuthenticatedOwnerAndReturnsTransportContract() {
        UUID userId = UUID.randomUUID();
        var expiry = Instant.parse("2026-10-01T00:10:00Z");
        when(storage.presignPut(anyString(), eq("image/png"), eq(128L), eq(Duration.ofMinutes(10))))
                .thenReturn(new ObjectStorageService.PresignedObject(
                        "https://private.example/put?signature=secret",
                        expiry,
                        Map.of("Content-Type", "image/png", "x-amz-meta-declared-size", "128")));

        var response = service.presign(userId, new PresignUploadRequest(
                UploadCategory.AVATAR, "../../avatar.png", "image/png", 128, null));

        assertTrue(response.storageKey().matches("avatar/" + userId + "/[0-9a-f-]{36}"));
        assertEquals("https://private.example/put?signature=secret", response.uploadUrl());
        assertEquals(expiry, response.expiresAt());
        assertEquals("image/png", response.requiredHeaders().get("Content-Type"));
        assertEquals("128", response.requiredHeaders().get("x-amz-meta-declared-size"));
        verify(storage).presignPut(response.storageKey(), "image/png", 128, Duration.ofMinutes(10));
    }

    @Test
    void avatarRejectsAnyContextBeforeSigning() {
        assertThrows(BusinessException.class, () -> service.presign(UUID.randomUUID(),
                new PresignUploadRequest(UploadCategory.AVATAR, "photo.png", "image/png", 10,
                        UUID.randomUUID().toString())));
        verifyNoInteractions(storage);
    }

    @Test
    void groupAvatarRequiresCanonicalContextAndPermissionBeforeSigning() {
        UUID userId = UUID.randomUUID();
        UUID groupId = UUID.randomUUID();
        when(storage.presignPut(anyString(), eq("image/jpeg"), eq(200L), eq(Duration.ofMinutes(10))))
                .thenReturn(new ObjectStorageService.PresignedObject("https://private.example/put",
                        Instant.now().plusSeconds(600), Map.of("Content-Type", "image/jpeg")));

        var response = service.presign(userId, new PresignUploadRequest(
                UploadCategory.GROUP_AVATAR, "g.jpg", "image/jpeg", 200, groupId.toString()));

        assertTrue(response.storageKey().startsWith("group-avatar/" + groupId + "/"));
        verify(groupPermissionService).requireCanModifyGroupInfo(groupId, userId);
    }

    @Test
    void groupAvatarRejectsMissingOrMalformedContext() {
        UUID userId = UUID.randomUUID();
        assertThrows(BusinessException.class, () -> service.presign(userId,
                new PresignUploadRequest(UploadCategory.GROUP_AVATAR, "g.jpg", "image/jpeg", 20, null)));
        assertThrows(BusinessException.class, () -> service.presign(userId,
                new PresignUploadRequest(UploadCategory.GROUP_AVATAR, "g.jpg", "image/jpeg", 20, "not-a-uuid")));
        verifyNoInteractions(groupPermissionService, storage);
    }

    @Test
    void validatesMimeAndSizeBeforeSigning() {
        UUID userId = UUID.randomUUID();
        assertThrows(BusinessException.class, () -> service.presign(userId,
                new PresignUploadRequest(UploadCategory.AVATAR, "a.svg", "image/svg+xml", 10, null)));
        assertThrows(BusinessException.class, () -> service.presign(userId,
                new PresignUploadRequest(UploadCategory.AVATAR, "a.png", "image/png", 0, null)));
        assertThrows(BusinessException.class, () -> service.presign(userId,
                new PresignUploadRequest(UploadCategory.AVATAR, "a.png", "image/png", 5L * 1024 * 1024 + 1, null)));
        verifyNoInteractions(storage);
    }
}
