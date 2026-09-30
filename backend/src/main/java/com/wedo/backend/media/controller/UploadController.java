package com.wedo.backend.media.controller;

import com.wedo.backend.media.dto.PresignUploadRequest;
import com.wedo.backend.media.dto.PresignUploadResponse;
import com.wedo.backend.media.service.UploadService;
import com.wedo.backend.security.AuthenticatedUserPrincipal;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/uploads")
public class UploadController {
    private final UploadService uploadService;

    public UploadController(UploadService uploadService) {
        this.uploadService = uploadService;
    }

    @PostMapping("/presign")
    public ResponseEntity<PresignUploadResponse> presign(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @Valid @RequestBody PresignUploadRequest request
    ) {
        return ResponseEntity.ok(uploadService.presign(principal.userId(), request));
    }
}
