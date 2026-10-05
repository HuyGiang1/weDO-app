package com.wedo.backend.media.controller;

import com.wedo.backend.media.dto.MediaUploadResponse;
import com.wedo.backend.media.dto.MediaAccessResponse;
import com.wedo.backend.media.service.MediaResource;
import com.wedo.backend.media.service.MediaService;
import com.wedo.backend.media.service.MediaUploadResult;
import java.time.Duration;
import java.util.UUID;
import org.springframework.core.io.Resource;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import com.wedo.backend.security.AuthenticatedUserPrincipal;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/v1/media")
public class MediaController {

    private final MediaService mediaService;

    public MediaController(MediaService mediaService) {
        this.mediaService = mediaService;
    }

    @PostMapping(value = "/avatar", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<MediaUploadResponse> uploadAvatar(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @RequestParam("file") MultipartFile file
    ) {
        MediaUploadResult result = mediaService.uploadAvatar(principal.userId(), file);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(new MediaUploadResponse(result.storageKey(), result.contentType(), result.size(), result.url()));
    }

    @GetMapping("/access")
    public ResponseEntity<MediaAccessResponse> getAuthorizedMediaAccess(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @RequestParam String storageKey
    ) {
        return ResponseEntity.ok(mediaService.authorizeRead(principal.userId(), storageKey));
    }

    @GetMapping("/{category}/{filename}")
    public ResponseEntity<Resource> getMedia(
            @PathVariable String category,
            @PathVariable String filename
    ) {
        MediaResource media = mediaService.loadMedia(category, filename);
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(media.contentType()))
                .cacheControl(CacheControl.maxAge(Duration.ofDays(1)).cachePublic())
                .body(media.resource());
    }
}
