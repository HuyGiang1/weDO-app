package com.wedo.backend.media.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static com.wedo.backend.media.service.MediaUploadAdmissionGuardTest.USER;
import com.wedo.backend.common.error.*;
import com.wedo.backend.group.service.GroupPermissionService;
import com.wedo.backend.group.repository.GroupRepository;
import com.wedo.backend.media.dto.*;
import com.wedo.backend.media.storage.ObjectStorageService;
import com.wedo.backend.chat.service.ChatService;
import com.wedo.backend.user.repository.UserRepository;
import com.wedo.backend.user.service.UserService;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.mock.env.MockEnvironment;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.util.ReflectionTestUtils;

class MediaUploadAdmissionPathsTest {
    private final ObjectStorageService storage = mock(ObjectStorageService.class);
    private final UserService users = mock(UserService.class);
    private final GroupPermissionService groups = mock(GroupPermissionService.class);
    private final MediaStorage local = mock(MediaStorage.class);
    private UploadService uploads(MediaUploadAdmissionGuard guard) {
        return new UploadService(storage, users, groups, guard);
    }
    private MediaService legacy(MediaUploadAdmissionGuard guard) {
        return new MediaService(local, users, storage, mock(UserRepository.class), mock(GroupRepository.class), guard);
    }
    private PresignUploadRequest request(UploadCategory category) {
        return new PresignUploadRequest(category, "synthetic.png", "image/png", 32,
                category == UploadCategory.AVATAR ? null : UUID.randomUUID().toString());
    }
    @ParameterizedTest @EnumSource(UploadCategory.class)
    void everyCategoryDeniedBeforeSigningWhenClosed(UploadCategory category) {
        var guard = MediaUploadAdmissionGuardTest.guard("false", USER.toString());
        assertThrows(BusinessException.class, () -> uploads(guard).presign(USER, request(category)));
        verify(users).requireActiveUser(USER);
        verifyNoInteractions(storage, groups);
    }
    @ParameterizedTest @EnumSource(UploadCategory.class)
    void everyCategoryDeniedForNonAllowlistedUserWhenOpen(UploadCategory category) {
        var guard = MediaUploadAdmissionGuardTest.guard("true", UUID.randomUUID().toString());
        assertThrows(BusinessException.class, () -> uploads(guard).presign(USER, request(category)));
        verifyNoInteractions(storage, groups);
    }
    @Test void stagingRejectsVideoBeforeAnySigningEvenWithImageMime() {
        var service = uploads(MediaUploadAdmissionGuardTest.guard("true", USER.toString()));
        for (String mime : new String[]{"video/mp4", "image/png"}) {
            assertThrows(BusinessException.class, () -> service.presign(USER,
                    new PresignUploadRequest(UploadCategory.MOMENT_VIDEO, "synthetic.mp4", mime, 128, UUID.randomUUID().toString())));
        }
        verifyNoInteractions(storage, groups);
    }
    @Test void nonStagingDoesNotApplyVideoRestriction() {
        var guard = new MediaUploadAdmissionGuard(new MockEnvironment());
        assertDoesNotThrow(() -> guard.requireImageUpload(UploadCategory.MOMENT_VIDEO, "video/mp4"));
    }
    @Test void stagingAvatarSizeBoundariesRetainExistingLimit() {
        var service = uploads(MediaUploadAdmissionGuardTest.guard("true", USER.toString()));
        when(storage.presignPut(anyString(), anyString(), anyLong(), any(Duration.class)))
                .thenReturn(new ObjectStorageService.PresignedObject("https://synthetic.invalid/put", Instant.now(), Map.of()));
        for (long size : new long[]{1, 5L * 1024 * 1024}) {
            assertDoesNotThrow(() -> service.presign(USER, new PresignUploadRequest(UploadCategory.AVATAR,
                    "synthetic.png", "image/png", size, null)));
        }
        clearInvocations(storage);
        for (long size : new long[]{0, -1, 5L * 1024 * 1024 + 1}) {
            assertThrows(BusinessException.class, () -> service.presign(USER, new PresignUploadRequest(UploadCategory.AVATAR,
                    "synthetic.png", "image/png", size, null)));
        }
        verifyNoInteractions(storage);
    }
    @Test void stagingImageSizeBoundariesRetainTenMiBLimit() {
        var service = uploads(MediaUploadAdmissionGuardTest.guard("true", USER.toString()));
        var references = mock(MediaReferenceService.class);
        ReflectionTestUtils.setField(service, "mediaReferences", references);
        ReflectionTestUtils.setField(service, "momentPolicy", new MomentMediaPolicy());
        when(references.newKey(any(), any(), any())).thenReturn("synthetic/image");
        when(storage.presignPut(anyString(), anyString(), anyLong(), anyString(), any(Duration.class)))
                .thenReturn(new ObjectStorageService.PresignedObject("https://synthetic.invalid/put", Instant.now(), Map.of()));
        for (long size : new long[]{1, 10L * 1024 * 1024}) {
            assertDoesNotThrow(() -> service.presign(USER, new PresignUploadRequest(UploadCategory.MOMENT_IMAGE,
                    "synthetic.png", "image/png", size, UUID.randomUUID().toString())));
        }
        clearInvocations(storage);
        for (long size : new long[]{0, -1, 10L * 1024 * 1024 + 1}) {
            assertThrows(BusinessException.class, () -> service.presign(USER, new PresignUploadRequest(UploadCategory.MOMENT_IMAGE,
                    "synthetic.png", "image/png", size, UUID.randomUUID().toString())));
        }
        verifyNoInteractions(storage);
    }
    @Test void approvedAvatarSignsWithExistingSizeMimeAndTtlContract() {
        when(storage.presignPut(anyString(), eq("image/png"), eq(32L), eq(Duration.ofMinutes(10))))
                .thenReturn(new ObjectStorageService.PresignedObject("https://synthetic.invalid/put", Instant.now(), Map.of()));
        var response = uploads(MediaUploadAdmissionGuardTest.guard("true", USER.toString()))
                .presign(USER, request(UploadCategory.AVATAR));
        assertTrue(response.storageKey().startsWith("avatar/" + USER + "/"));
        verify(storage).presignPut(anyString(), eq("image/png"), eq(32L), eq(Duration.ofMinutes(10)));
    }
    @Test void allowedUserStillRequiresActiveAccount() {
        doThrow(new BusinessException(ErrorCode.ACCOUNT_SUSPENDED)).when(users).requireActiveUser(USER);
        var failure = assertThrows(BusinessException.class, () -> uploads(
                MediaUploadAdmissionGuardTest.guard("true", USER.toString())).presign(USER, request(UploadCategory.AVATAR)));
        assertEquals(ErrorCode.ACCOUNT_SUSPENDED, failure.errorCode());
        verifyNoInteractions(storage);
    }
    @Test void allowlistDoesNotGrantGroupAvatarPermission() {
        doThrow(new BusinessException(ErrorCode.ACCESS_DENIED)).when(groups).requireCanModifyGroupInfo(any(), eq(USER));
        assertThrows(BusinessException.class, () -> uploads(MediaUploadAdmissionGuardTest.guard("true", USER.toString()))
                .presign(USER, request(UploadCategory.GROUP_AVATAR)));
        verify(groups).requireCanModifyGroupInfo(any(), eq(USER));
        verifyNoInteractions(storage);
    }
    @Test void allowlistDoesNotGrantChatPermission() {
        var service = uploads(MediaUploadAdmissionGuardTest.guard("true", USER.toString()));
        var chat = mock(ChatService.class);
        ReflectionTestUtils.setField(service, "chatService", chat);
        ReflectionTestUtils.setField(service, "mediaReferences", mock(MediaReferenceService.class));
        assertThrows(BusinessException.class, () -> service.presign(USER, request(UploadCategory.CHAT_IMAGE)));
        verify(chat).canSendImageInConversation(any(), eq(USER));
        verifyNoInteractions(storage);
    }
    @Test void legacyAvatarCannotBypassClosedGuardOrReadMultipartBytes() {
        var file = mock(org.springframework.web.multipart.MultipartFile.class);
        assertThrows(BusinessException.class, () -> legacy(MediaUploadAdmissionGuardTest.guard(null, null))
                .uploadAvatar(USER, file));
        verify(users).requireActiveUser(USER);
        verifyNoInteractions(file, local, storage);
    }
    @Test void nonStagingLegacyAvatarKeepsExistingPath() {
        var file = new MockMultipartFile("file", "synthetic.png", "image/png", new byte[]{1,2,3});
        legacy(new MediaUploadAdmissionGuard(new MockEnvironment())).uploadAvatar(USER, file);
        verify(local).storeAvatar(any(), eq("image/png"), eq("synthetic.png"));
        verifyNoInteractions(storage);
    }
    @Test void springInjectsRequiredGuardAndMissingStagingSettingsAreClosed() {
        new ApplicationContextRunner()
                .withInitializer(context -> context.getEnvironment().setActiveProfiles("staging"))
                .withUserConfiguration(MediaUploadAdmissionGuard.class, UploadService.class, MediaService.class)
                .withBean(ObjectStorageService.class, () -> storage).withBean(UserService.class, () -> users)
                .withBean(GroupPermissionService.class, () -> groups).withBean(MediaStorage.class, () -> local)
                .withBean(UserRepository.class, () -> mock(UserRepository.class))
                .withBean(GroupRepository.class, () -> mock(GroupRepository.class))
                .withBean(MomentMediaPolicy.class, () -> mock(MomentMediaPolicy.class))
                .run(context -> {
                    assertNull(context.getStartupFailure());
                    assertThrows(BusinessException.class, () -> context.getBean(UploadService.class)
                            .presign(USER, request(UploadCategory.AVATAR)));
                    assertThrows(BusinessException.class, () -> context.getBean(MediaService.class).uploadAvatar(USER, null));
                    verifyNoInteractions(local, storage);
                });
    }
}
