package com.wedo.backend.media.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.media.dto.UploadCategory;
import com.wedo.backend.media.storage.ObjectStorageService;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class MediaReferenceServiceTest {
    private final ObjectStorageService storage = mock(ObjectStorageService.class);
    private final MediaReferenceService references = new MediaReferenceService(storage);

    @Test
    void generatedReferenceBindsCategoryContextUploaderAndActualObjectMetadata() {
        UUID context = UUID.randomUUID();
        UUID uploader = UUID.randomUUID();
        String key = references.newKey(UploadCategory.CHAT_IMAGE, context, uploader);
        when(storage.head(key)).thenReturn(new ObjectStorageService.ObjectMetadata(
                "image/webp", 42, Map.of("declared-size", "42")));

        var parsed = references.validate(key, UploadCategory.CHAT_IMAGE, context, uploader);

        assertEquals(UploadCategory.CHAT_IMAGE, parsed.category());
        assertEquals(context, parsed.contextId());
        assertEquals(uploader, parsed.uploaderId());
        assertEquals(key, "chat/" + context + "/" + uploader + "/" + parsed.objectId());
        assertThrows(BusinessException.class,
                () -> references.validate(key, UploadCategory.EXPENSE_RECEIPT, context, uploader));
        assertThrows(BusinessException.class,
                () -> references.validate(key, UploadCategory.CHAT_IMAGE, UUID.randomUUID(), uploader));
        assertThrows(BusinessException.class,
                () -> references.validate(key, UploadCategory.CHAT_IMAGE, context, UUID.randomUUID()));
    }

    @Test
    void rejectsUnsupportedMimeAndDeclaredSizeMismatch() {
        UUID context = UUID.randomUUID();
        UUID uploader = UUID.randomUUID();
        String key = references.newKey(UploadCategory.EXPENSE_RECEIPT, context, uploader);
        when(storage.head(key)).thenReturn(new ObjectStorageService.ObjectMetadata(
                "application/pdf", 42, Map.of("declared-size", "42")));
        assertThrows(BusinessException.class,
                () -> references.validate(key, UploadCategory.EXPENSE_RECEIPT, context, uploader));

        when(storage.head(key)).thenReturn(new ObjectStorageService.ObjectMetadata(
                "image/jpeg", 42, Map.of("declared-size", "41")));
        assertThrows(BusinessException.class,
                () -> references.validate(key, UploadCategory.EXPENSE_RECEIPT, context, uploader));
    }
}
