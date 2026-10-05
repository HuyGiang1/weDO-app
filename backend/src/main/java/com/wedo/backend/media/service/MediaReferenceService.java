package com.wedo.backend.media.service;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.media.dto.UploadCategory;
import com.wedo.backend.media.storage.ObjectStorageException;
import com.wedo.backend.media.storage.ObjectStorageService;
import java.util.Locale;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.UUID;
import java.util.regex.Pattern;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

@Service
public class MediaReferenceService {
    public static final long A2_MAX_BYTES = 10L * 1024 * 1024;
    public static final java.util.Set<String> IMAGE_TYPES = java.util.Set.of(
            "image/jpeg", "image/png", "image/webp");

    private static final Pattern KEY = Pattern.compile(
            "^(chat|expense-receipt|fund-contribution-proof|fund-expense-receipt|fund-reimbursement-receipt)/"
                    + "([0-9a-fA-F-]{36})/([0-9a-fA-F-]{36})/([0-9a-fA-F-]{36})$");

    private final ObjectStorageService storage;

    public MediaReferenceService(ObjectStorageService storage) {
        this.storage = storage;
    }

    public String newKey(UploadCategory category, UUID contextId, UUID uploaderId) {
        String namespace = namespace(category);
        return namespace + "/" + contextId + "/" + uploaderId + "/" + UUID.randomUUID();
    }

    public ParsedKey validate(String storageKey, UploadCategory expectedCategory,
                              UUID expectedContextId, UUID expectedUploaderId) {
        var matcher = KEY.matcher(storageKey == null ? "" : storageKey);
        if (!matcher.matches()) throw invalidReference();
        ParsedKey parsed;
        try {
            UUID context = UUID.fromString(matcher.group(2));
            UUID uploader = UUID.fromString(matcher.group(3));
            UUID objectId = UUID.fromString(matcher.group(4));
            if (!context.toString().equalsIgnoreCase(matcher.group(2))
                    || !uploader.toString().equalsIgnoreCase(matcher.group(3))
                    || !objectId.toString().equalsIgnoreCase(matcher.group(4))) throw invalidReference();
            parsed = new ParsedKey(category(matcher.group(1)), context, uploader, objectId);
        } catch (IllegalArgumentException exception) {
            throw invalidReference();
        }
        if (parsed.category() != expectedCategory
                || !parsed.contextId().equals(expectedContextId)
                || !parsed.uploaderId().equals(expectedUploaderId)) {
            throw invalidReference();
        }
        validateObject(storageKey);
        return parsed;
    }

    public ParsedKey parse(String storageKey) {
        var matcher = KEY.matcher(storageKey == null ? "" : storageKey);
        if (!matcher.matches()) return null;
        try {
            UUID context = UUID.fromString(matcher.group(2));
            UUID uploader = UUID.fromString(matcher.group(3));
            UUID objectId = UUID.fromString(matcher.group(4));
            if (!context.toString().equalsIgnoreCase(matcher.group(2))
                    || !uploader.toString().equalsIgnoreCase(matcher.group(3))
                    || !objectId.toString().equalsIgnoreCase(matcher.group(4))) return null;
            return new ParsedKey(category(matcher.group(1)), context, uploader, objectId);
        } catch (IllegalArgumentException exception) {
            return null;
        }
    }

    public String originalFileName(String storageKey) {
        try {
            var metadata = storage.head(storageKey).metadata();
            String encoded = metadata == null ? null : metadata.get("original-file-name");
            if (encoded == null) return null;
            String decoded = new String(Base64.getUrlDecoder().decode(encoded), StandardCharsets.UTF_8)
                    .replace('\\', '/');
            String fileName = decoded.substring(decoded.lastIndexOf('/') + 1)
                    .replaceAll("[\\p{Cntrl}]", "").trim();
            if (fileName.isBlank()) return null;
            return fileName.length() <= 255 ? fileName : fileName.substring(fileName.length() - 255);
        } catch (RuntimeException exception) {
            return null;
        }
    }

    public String contentType(String storageKey) {
        return storage.head(storageKey).contentType();
    }

    public long fileSize(String storageKey) {
        return storage.head(storageKey).size();
    }

    public void deleteAfterCommit(String oldKey, String newKey) {
        if (oldKey == null || oldKey.isBlank() || oldKey.equals(newKey)) return;
        if (!TransactionSynchronizationManager.isSynchronizationActive()) return;
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override
            public void afterCommit() {
                try {
                    storage.delete(oldKey);
                } catch (RuntimeException ignored) {
                    // Object cleanup must not undo a committed business mutation.
                }
            }
        });
    }

    private void validateObject(String storageKey) {
        try {
            ObjectStorageService.ObjectMetadata metadata = storage.head(storageKey);
            String contentType = metadata.contentType() == null
                    ? "" : metadata.contentType().toLowerCase(Locale.ROOT);
            String declaredSize = metadata.metadata() == null ? null : metadata.metadata().get("declared-size");
            if (!IMAGE_TYPES.contains(contentType)
                    || metadata.size() <= 0 || metadata.size() > A2_MAX_BYTES
                    || declaredSize == null || !Long.toString(metadata.size()).equals(declaredSize)) {
                throw invalidReference();
            }
        } catch (ObjectStorageException exception) {
            throw invalidReference();
        }
    }

    private String namespace(UploadCategory category) {
        return switch (category) {
            case CHAT_IMAGE -> "chat";
            case EXPENSE_RECEIPT -> "expense-receipt";
            case FUND_CONTRIBUTION_PROOF -> "fund-contribution-proof";
            case FUND_EXPENSE_RECEIPT -> "fund-expense-receipt";
            case FUND_REIMBURSEMENT_RECEIPT -> "fund-reimbursement-receipt";
            default -> throw invalidReference();
        };
    }

    private UploadCategory category(String namespace) {
        return switch (namespace) {
            case "chat" -> UploadCategory.CHAT_IMAGE;
            case "expense-receipt" -> UploadCategory.EXPENSE_RECEIPT;
            case "fund-contribution-proof" -> UploadCategory.FUND_CONTRIBUTION_PROOF;
            case "fund-expense-receipt" -> UploadCategory.FUND_EXPENSE_RECEIPT;
            case "fund-reimbursement-receipt" -> UploadCategory.FUND_REIMBURSEMENT_RECEIPT;
            default -> throw invalidReference();
        };
    }

    private BusinessException invalidReference() {
        return new BusinessException(ErrorCode.VALIDATION_FAILED);
    }

    public record ParsedKey(UploadCategory category, UUID contextId, UUID uploaderId, UUID objectId) { }
}
