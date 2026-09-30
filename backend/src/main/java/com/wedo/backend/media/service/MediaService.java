package com.wedo.backend.media.service;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.user.service.UserService;
import com.wedo.backend.user.repository.UserRepository;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.group.repository.GroupRepository;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.media.dto.MediaAccessResponse;
import com.wedo.backend.media.storage.ObjectStorageService;
import com.wedo.backend.chat.service.ChatService;
import com.wedo.backend.expense.service.ExpenseService;
import com.wedo.backend.fund.service.FundService;
import java.io.IOException;
import java.time.Duration;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

@Service
public class MediaService {

    private static final long MAX_AVATAR_SIZE = 5 * 1024 * 1024; // 5MB

    private final MediaStorage mediaStorage;
    private final UserService userService;
    private final ObjectStorageService objectStorageService;
    private final UserRepository userRepository;
    private final GroupRepository groupRepository;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private MediaReferenceService mediaReferences;
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private ChatService chatService;
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private ExpenseService expenseService;
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private FundService fundService;

    public MediaService(MediaStorage mediaStorage, UserService userService,
                        ObjectStorageService objectStorageService,
                        UserRepository userRepository, GroupRepository groupRepository) {
        this.mediaStorage = mediaStorage;
        this.userService = userService;
        this.objectStorageService = objectStorageService;
        this.userRepository = userRepository;
        this.groupRepository = groupRepository;
    }

    public MediaUploadResult uploadAvatar(UUID callerUserId, MultipartFile file) {
        userService.requireActiveUser(callerUserId);
        if (file == null || file.isEmpty()) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
        if (file.getSize() > MAX_AVATAR_SIZE) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
        try {
            return mediaStorage.storeAvatar(file.getBytes(), file.getContentType(), file.getOriginalFilename());
        } catch (IOException e) {
            throw new BusinessException(ErrorCode.INTERNAL_SERVER_ERROR);
        }
    }

    public MediaResource loadMedia(String category, String filename) {
        if (category == null || filename == null || category.isBlank() || filename.isBlank()) {
            throw new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);
        }
        String storageKey = category + "/" + filename;
        return mediaStorage.load(storageKey)
                .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));
    }

    public MediaAccessResponse authorizeRead(UUID callerId, String storageKey) {
        userService.requireActiveUser(callerId);
        if (storageKey == null) throw new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);
        MediaReferenceService.ParsedKey parsed = mediaReferences == null ? null : mediaReferences.parse(storageKey);
        if (parsed != null) {
            switch (parsed.category()) {
                case CHAT_IMAGE -> {
                    if (chatService == null) throw new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);
                    chatService.requireAttachmentReadable(storageKey, callerId);
                }
                case EXPENSE_RECEIPT -> {
                    if (expenseService == null) throw new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);
                    expenseService.requireReceiptReadable(storageKey, callerId, parsed.contextId());
                }
                case FUND_CONTRIBUTION_PROOF, FUND_EXPENSE_RECEIPT, FUND_REIMBURSEMENT_RECEIPT -> {
                    if (fundService == null) throw new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);
                    fundService.requireMediaReadable(parsed.category(), storageKey, parsed.contextId(), callerId);
                }
                default -> throw new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);
            }
            return signedRead(storageKey);
        }
        var avatarMatcher = java.util.regex.Pattern
                .compile("^avatar/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})$")
                .matcher(storageKey);
        var groupMatcher = java.util.regex.Pattern
                .compile("^group-avatar/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})$")
                .matcher(storageKey);
        if (avatarMatcher.matches()) {
            UUID owner = UUID.fromString(avatarMatcher.group(1));
            userRepository.findById(owner)
                    .filter(user -> user.getStatus() == UserStatus.ACTIVE)
                    .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));
        } else if (groupMatcher.matches()) {
            UUID groupId = UUID.fromString(groupMatcher.group(1));
            groupRepository.findById(groupId)
                    .filter(group -> group.getStatus() != GroupStatus.DELETED)
                    .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));
        } else {
            throw new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);
        }
        return signedRead(storageKey);
    }

    private MediaAccessResponse signedRead(String storageKey) {
        try {
            objectStorageService.head(storageKey);
            var signed = objectStorageService.presignGet(storageKey, Duration.ofMinutes(5));
            return new MediaAccessResponse(signed.url(), signed.expiresAt());
        } catch (RuntimeException exception) {
            throw new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);
        }
    }
}
