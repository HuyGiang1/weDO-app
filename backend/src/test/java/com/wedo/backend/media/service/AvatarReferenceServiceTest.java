package com.wedo.backend.media.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.media.storage.ObjectStorageException;
import com.wedo.backend.media.storage.ObjectStorageService;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class AvatarReferenceServiceTest {
    private final ObjectStorageService storage = mock(ObjectStorageService.class);
    private final AvatarReferenceService service = new AvatarReferenceService(storage);

    @Test
    void profileReferenceMustMatchOwnerNamespaceAndStoredMetadata() {
        UUID owner = UUID.randomUUID();
        String key = "avatar/" + owner + "/" + UUID.randomUUID();
        when(storage.head(key)).thenReturn(new ObjectStorageService.ObjectMetadata(
                "image/jpeg", 64, Map.of("declared-size", "64")));

        service.validateProfileKey(owner, key);

        assertTrue(service.isOwnedAvatarKey(key));
        verify(storage).head(key);
    }

    @Test
    void rejectsCrossOwnerWrongPurposeTraversalMissingObjectAndMetadataMismatch() {
        UUID owner = UUID.randomUUID();
        String otherOwnerKey = "avatar/" + UUID.randomUUID() + "/" + UUID.randomUUID();
        String groupKey = "group-avatar/" + owner + "/" + UUID.randomUUID();
        String validKey = "avatar/" + owner + "/" + UUID.randomUUID();
        assertThrows(BusinessException.class, () -> service.validateProfileKey(owner, otherOwnerKey));
        assertThrows(BusinessException.class, () -> service.validateProfileKey(owner, groupKey));
        assertThrows(BusinessException.class, () -> service.validateProfileKey(owner, "../" + validKey));

        when(storage.head(validKey)).thenReturn(new ObjectStorageService.ObjectMetadata(
                "image/jpeg", 128, Map.of("declared-size", "64")));
        assertThrows(BusinessException.class, () -> service.validateProfileKey(owner, validKey));

        String missing = "avatar/" + owner + "/" + UUID.randomUUID();
        when(storage.head(missing)).thenThrow(new ObjectStorageException("missing", null));
        assertThrows(BusinessException.class, () -> service.validateProfileKey(owner, missing));
    }

    @Test
    void rejectsGroupKeyBoundToDifferentGroup() {
        UUID group = UUID.randomUUID();
        String key = "group-avatar/" + UUID.randomUUID() + "/" + UUID.randomUUID();
        assertThrows(BusinessException.class, () -> service.validateGroupKey(group, key));
        verifyNoInteractions(storage);
    }
}
