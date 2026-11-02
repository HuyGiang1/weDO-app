package com.wedo.backend.media.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import com.wedo.backend.common.error.*;
import com.wedo.backend.media.dto.*;
import com.wedo.backend.media.storage.ObjectStorageService;
import com.wedo.backend.user.service.UserService;
import com.wedo.backend.group.service.GroupPermissionService;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.springframework.mock.env.MockEnvironment;
import org.springframework.test.util.ReflectionTestUtils;

class StagingMediaBudgetPolicyTest {
    static final UUID USER = UUID.randomUUID();
    MockEnvironment env() {
        var e = new MockEnvironment().withProperty("wedo.staging.media-upload.enabled", "true")
                .withProperty("wedo.staging.media-upload.allowed-user-ids", USER.toString());
        e.setActiveProfiles("staging"); return e;
    }
    @ParameterizedTest
    @CsvSource({"max-image-bytes,5242881", "max-video-bytes,20971521", "quota-bytes,157286401",
            "max-requests,6", "window-seconds,599", "window-seconds,99999999999999",
            "quota-bytes,-1", "quota-bytes,invalid", "video-enabled,TRUE"})
    void unsafeConfigurationClosesInsteadOfWeakeningApprovedCaps(String key, String value) {
        var e=env().withProperty("wedo.staging.media-upload."+key,value);
        var error=assertThrows(BusinessException.class,()->new MediaUploadAdmissionGuard(e).requireAllowed(USER));
        assertEquals(ErrorCode.STAGING_MEDIA_UPLOAD_DISABLED,error.errorCode());
    }
    @Test void closedAndWrongAccountHaveDistinctSafeErrors() {
        var e=env(); e.setProperty("wedo.staging.media-upload.enabled","false");
        assertEquals(ErrorCode.STAGING_MEDIA_UPLOAD_DISABLED,assertThrows(BusinessException.class,
                ()->new MediaUploadAdmissionGuard(e).requireAllowed(USER)).errorCode());
        assertEquals(ErrorCode.STAGING_MEDIA_UPLOAD_NOT_ALLOWED,assertThrows(BusinessException.class,
                ()->new MediaUploadAdmissionGuard(env()).requireAllowed(UUID.randomUUID())).errorCode());
    }
    @Test void exactImageAndVideoBoundariesAndVideoOptIn() {
        var guard=new MediaUploadAdmissionGuard(env().withProperty("wedo.staging.media-upload.video-enabled","true"));
        assertDoesNotThrow(()->guard.requireSize(UploadCategory.CHAT_IMAGE,5*1024*1024));
        assertThrows(BusinessException.class,()->guard.requireSize(UploadCategory.CHAT_IMAGE,5*1024*1024+1));
        assertDoesNotThrow(()->guard.requireSize(UploadCategory.MOMENT_VIDEO,20*1024*1024));
        assertThrows(BusinessException.class,()->guard.requireSize(UploadCategory.MOMENT_VIDEO,20*1024*1024+1));
        assertDoesNotThrow(()->guard.requireImageUpload(UploadCategory.MOMENT_VIDEO,"video/mp4"));
        assertThrows(BusinessException.class,()->guard.requireImageUpload(UploadCategory.MOMENT_VIDEO,"image/png"));
        assertThrows(BusinessException.class,()->new MediaUploadAdmissionGuard(env()).requireImageUpload(UploadCategory.MOMENT_VIDEO,"video/mp4"));
    }
    @Test void missingLedgerFailsBeforeSigningAndDoesNotFallback() {
        var guard=new MediaUploadAdmissionGuard(env()); var storage=mock(ObjectStorageService.class);
        var service=new UploadService(storage,mock(UserService.class),mock(GroupPermissionService.class),guard);
        assertEquals(ErrorCode.INTERNAL_SERVER_ERROR,assertThrows(BusinessException.class,()->service.presign(USER,
                new PresignUploadRequest(UploadCategory.AVATAR,"synthetic.png","image/png",32,null))).errorCode());
        verifyNoInteractions(storage);
    }
    @Test void storageIsNotCalledOnBudgetRejectionAndNoClientKeyCanBypassReservation() {
        var guard=new MediaUploadAdmissionGuard(env()); var ledger=mock(StagingMediaReservationService.class);
        ReflectionTestUtils.setField(guard,"reservations",ledger);
        doThrow(new BusinessException(ErrorCode.STAGING_MEDIA_QUOTA_EXCEEDED)).when(ledger)
                .reserve(eq(USER),anyString(),eq(32L),eq(157286400L),eq(5),eq(600L));
        var storage=mock(ObjectStorageService.class);
        var service=new UploadService(storage,mock(UserService.class),mock(GroupPermissionService.class),guard);
        assertEquals(ErrorCode.STAGING_MEDIA_QUOTA_EXCEEDED,assertThrows(BusinessException.class,()->service.presign(USER,
                new PresignUploadRequest(UploadCategory.AVATAR,"synthetic.png","image/png",32,null))).errorCode());
        verify(ledger).reserve(eq(USER),matches("avatar/"+USER+"/[0-9a-f-]{36}"),eq(32L),eq(157286400L),eq(5),eq(600L));
        verifyNoInteractions(storage);
    }
    @Test void legacyAvatarCannotBypassBudgetEvenWhenAllowlistOpen() {
        var guard=new MediaUploadAdmissionGuard(env());
        assertEquals(ErrorCode.STAGING_MEDIA_PRESIGN_REQUIRED,assertThrows(BusinessException.class,
                ()->guard.requireLegacyUpload(USER)).errorCode());
    }
    @Test void optedInVideoPresignStillRequiresGroupPermissionAndReservationBeforeSigning() {
        var guard = new MediaUploadAdmissionGuard(env().withProperty("wedo.staging.media-upload.video-enabled", "true"));
        var ledger = mock(StagingMediaReservationService.class);
        ReflectionTestUtils.setField(guard, "reservations", ledger);
        var storage = mock(ObjectStorageService.class);
        var groups = mock(GroupPermissionService.class);
        var references = mock(MediaReferenceService.class);
        var service = new UploadService(storage, mock(UserService.class), groups, guard);
        ReflectionTestUtils.setField(service, "mediaReferences", references);
        ReflectionTestUtils.setField(service, "momentPolicy", new MomentMediaPolicy());
        UUID group = UUID.randomUUID();
        when(references.newKey(UploadCategory.MOMENT_VIDEO, group, USER)).thenReturn("synthetic/video");
        when(storage.presignPut(anyString(), anyString(), anyLong(), anyString(), any(java.time.Duration.class)))
                .thenReturn(new ObjectStorageService.PresignedObject("https://synthetic.invalid/put", java.time.Instant.now(), java.util.Map.of()));
        service.presign(USER, new PresignUploadRequest(UploadCategory.MOMENT_VIDEO, "synthetic.mp4", "video/mp4", 20L*1024*1024, group.toString()));
        var order = inOrder(groups, ledger, storage);
        order.verify(groups).requireMutableMembership(group, USER);
        order.verify(ledger).reserve(USER, "synthetic/video", 20L*1024*1024, 150L*1024*1024, 5, 600);
        order.verify(storage).presignPut(eq("synthetic/video"), eq("video/mp4"), eq(20L*1024*1024), eq("synthetic.mp4"), any(java.time.Duration.class));
    }
    @Test void nonStagingDoesNotConsultLedgerOrStagingLimits() {
        var e=new MockEnvironment().withProperty("wedo.staging.media-upload.quota-bytes","INVALID");
        var guard=new MediaUploadAdmissionGuard(e);
        assertDoesNotThrow(()->guard.reserve(USER,"synthetic",Long.MAX_VALUE));
        assertDoesNotThrow(()->guard.requireSize(UploadCategory.CHAT_IMAGE,Long.MAX_VALUE));
        assertDoesNotThrow(()->guard.requireLegacyUpload(USER));
    }
}
