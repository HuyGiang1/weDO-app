package com.wedo.backend.media.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.group.repository.GroupRepository;
import com.wedo.backend.media.storage.ObjectStorageService;
import com.wedo.backend.user.repository.UserRepository;
import com.wedo.backend.user.service.UserService;
import org.junit.jupiter.api.Test;

class MediaServiceLegacyAccessTest {
    private final MediaStorage localStorage = mock(MediaStorage.class);
    private final MediaService media = new MediaService(localStorage, mock(UserService.class),
            mock(ObjectStorageService.class), mock(UserRepository.class), mock(GroupRepository.class));

    @Test
    void publicLegacyReaderNeverLoadsNonAvatarCategories() {
        for (String category : new String[]{"chat", "expense-receipt", "fund-contribution-proof", "private"}) {
            BusinessException error = assertThrows(BusinessException.class,
                    () -> media.loadMedia(category, "known-object"));
            assertEquals(ErrorCode.RESOURCE_NOT_FOUND, error.errorCode());
        }
        verifyNoInteractions(localStorage);
    }
}
