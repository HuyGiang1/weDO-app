package com.wedo.backend.media.service;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.media.storage.ObjectStorageException;
import com.wedo.backend.media.storage.ObjectStorageService;
import java.util.Locale;
import java.util.UUID;
import org.springframework.stereotype.Service;

@Service
public class AvatarReferenceService {
    private static final long MAX_SIZE = 5L * 1024 * 1024;
    private static final java.util.Set<String> CONTENT_TYPES = java.util.Set.of(
            "image/jpeg", "image/png", "image/webp");
    private static final java.util.regex.Pattern AVATAR_KEY = java.util.regex.Pattern.compile(
            "^avatar/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})$");
    private static final java.util.regex.Pattern GROUP_KEY = java.util.regex.Pattern.compile(
            "^group-avatar/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})$");

    private final ObjectStorageService storage;

    public AvatarReferenceService(ObjectStorageService storage) {
        this.storage = storage;
    }

    public void validateProfileKey(UUID ownerId, String storageKey) {
        var matcher = AVATAR_KEY.matcher(storageKey == null ? "" : storageKey);
        if (!matcher.matches() || !UUID.fromString(matcher.group(1)).equals(ownerId)) {
            throw invalidReference();
        }
        validateObject(storageKey);
    }

    public void validateGroupKey(UUID groupId, String storageKey) {
        var matcher = GROUP_KEY.matcher(storageKey == null ? "" : storageKey);
        if (!matcher.matches() || !UUID.fromString(matcher.group(1)).equals(groupId)) {
            throw invalidReference();
        }
        validateObject(storageKey);
    }

    public void deleteAfterCommit(String oldKey, String newKey) {
        if (oldKey == null || oldKey.isBlank() || oldKey.equals(newKey)) return;
        org.springframework.transaction.support.TransactionSynchronizationManager.registerSynchronization(
                new org.springframework.transaction.support.TransactionSynchronization() {
                    @Override
                    public void afterCommit() {
                        try {
                            storage.delete(oldKey);
                        } catch (RuntimeException ignored) {
                            // Cleanup must never undo a committed avatar replacement.
                        }
                    }
                });
    }

    public boolean isOwnedAvatarKey(String storageKey) {
        return storageKey != null && (AVATAR_KEY.matcher(storageKey).matches()
                || GROUP_KEY.matcher(storageKey).matches());
    }

    private void validateObject(String storageKey) {
        try {
            ObjectStorageService.ObjectMetadata metadata = storage.head(storageKey);
            String contentType = metadata.contentType() == null
                    ? "" : metadata.contentType().toLowerCase(Locale.ROOT);
            String declaredSize = metadata.metadata() == null ? null : metadata.metadata().get("declared-size");
            if (!CONTENT_TYPES.contains(contentType)
                    || metadata.size() <= 0 || metadata.size() > MAX_SIZE
                    || declaredSize == null || !Long.toString(metadata.size()).equals(declaredSize)) {
                throw invalidReference();
            }
        } catch (ObjectStorageException exception) {
            throw invalidReference();
        }
    }

    private BusinessException invalidReference() {
        return new BusinessException(ErrorCode.VALIDATION_FAILED);
    }
}
