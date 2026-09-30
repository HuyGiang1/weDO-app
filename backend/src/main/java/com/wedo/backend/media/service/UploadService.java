package com.wedo.backend.media.service;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.chat.service.ChatService;
import com.wedo.backend.expense.service.ExpenseService;
import com.wedo.backend.fund.service.FundService;
import com.wedo.backend.group.service.GroupPermissionService;
import com.wedo.backend.media.dto.PresignUploadRequest;
import com.wedo.backend.media.dto.PresignUploadResponse;
import com.wedo.backend.media.dto.UploadCategory;
import com.wedo.backend.media.storage.ObjectStorageService;
import com.wedo.backend.security.AuthenticatedUserPrincipal;
import com.wedo.backend.user.service.UserService;
import java.time.Duration;
import java.util.Locale;
import java.util.UUID;
import org.springframework.stereotype.Service;

@Service
public class UploadService {
    private static final long MAX_AVATAR_BYTES = 5L * 1024 * 1024;
    private static final Duration UPLOAD_EXPIRY = Duration.ofMinutes(10);
    private static final java.util.Set<String> IMAGE_TYPES = java.util.Set.of(
            "image/jpeg", "image/png", "image/webp");

    private final ObjectStorageService storage;
    private final UserService userService;
    private final GroupPermissionService groupPermissionService;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private MediaReferenceService mediaReferences;
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private ChatService chatService;
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private ExpenseService expenseService;
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private FundService fundService;

    public UploadService(ObjectStorageService storage, UserService userService,
                         GroupPermissionService groupPermissionService) {
        this.storage = storage;
        this.userService = userService;
        this.groupPermissionService = groupPermissionService;
    }

    public PresignUploadResponse presign(UUID callerId, PresignUploadRequest request) {
        userService.requireActiveUser(callerId);
        String contentType = request.contentType().trim().toLowerCase(Locale.ROOT);
        boolean a2 = request.category() != UploadCategory.AVATAR && request.category() != UploadCategory.GROUP_AVATAR;
        long maxBytes = a2 ? MediaReferenceService.A2_MAX_BYTES : MAX_AVATAR_BYTES;
        if (!IMAGE_TYPES.contains(contentType) || request.fileSize() <= 0 || request.fileSize() > maxBytes) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }

        String key;
        if (request.category() == UploadCategory.AVATAR) {
            if (request.contextId() != null) throw new BusinessException(ErrorCode.VALIDATION_FAILED);
            key = "avatar/" + callerId + "/" + UUID.randomUUID();
        } else if (request.category() == UploadCategory.GROUP_AVATAR) {
            UUID groupId = parseGroupId(request.contextId());
            groupPermissionService.requireCanModifyGroupInfo(groupId, callerId);
            key = "group-avatar/" + groupId + "/" + UUID.randomUUID();
        } else if (a2) {
            UUID contextId = parseGroupId(request.contextId());
            if (mediaReferences == null) throw new BusinessException(ErrorCode.INTERNAL_SERVER_ERROR);
            switch (request.category()) {
                case CHAT_IMAGE -> {
                    if (chatService == null || !chatService.canSendImageInConversation(contextId, callerId)) {
                        throw new BusinessException(ErrorCode.ACCESS_DENIED);
                    }
                }
                case EXPENSE_RECEIPT -> {
                    if (expenseService == null) throw new BusinessException(ErrorCode.INTERNAL_SERVER_ERROR);
                    expenseService.authorizeReceiptPresign(contextId, callerId);
                }
                case FUND_CONTRIBUTION_PROOF, FUND_EXPENSE_RECEIPT, FUND_REIMBURSEMENT_RECEIPT -> {
                    if (fundService == null) throw new BusinessException(ErrorCode.INTERNAL_SERVER_ERROR);
                    fundService.authorizeMediaPresign(request.category(), contextId, callerId);
                }
                default -> throw new BusinessException(ErrorCode.VALIDATION_FAILED);
            }
            key = mediaReferences.newKey(request.category(), contextId, callerId);
        } else {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }

        ObjectStorageService.PresignedObject target = a2
                ? storage.presignPut(key, contentType, request.fileSize(), request.fileName().trim(), UPLOAD_EXPIRY)
                : storage.presignPut(key, contentType, request.fileSize(), UPLOAD_EXPIRY);
        return new PresignUploadResponse(key, target.url(), target.expiresAt(), target.requiredHeaders());
    }

    private UUID parseGroupId(String contextId) {
        if (contextId == null || contextId.isBlank()) throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        try {
            UUID groupId = UUID.fromString(contextId);
            if (!groupId.toString().equalsIgnoreCase(contextId)) {
                throw new BusinessException(ErrorCode.VALIDATION_FAILED);
            }
            return groupId;
        } catch (IllegalArgumentException exception) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
    }
}
