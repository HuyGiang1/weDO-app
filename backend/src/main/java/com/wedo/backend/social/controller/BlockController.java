package com.wedo.backend.social.controller;

import com.wedo.backend.common.dto.PagedResponse;
import com.wedo.backend.security.AuthenticatedUserPrincipal;
import com.wedo.backend.social.dto.BlockedUserResponse;
import com.wedo.backend.social.service.BlockService;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1")
public class BlockController {

    private final BlockService blockService;

    public BlockController(BlockService blockService) {
        this.blockService = blockService;
    }

    @PostMapping("/users/{userId}/block")
    public ResponseEntity<Void> blockUser(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable("userId") UUID userId
    ) {
        blockService.blockUser(principal.userId(), userId);
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/users/{userId}/block")
    public ResponseEntity<Void> unblockUser(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable("userId") UUID userId
    ) {
        blockService.unblockUser(principal.userId(), userId);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/me/blocked-users")
    public ResponseEntity<PagedResponse<BlockedUserResponse>> getBlockedUsers(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PageableDefault(size = 30) Pageable pageable
    ) {
        PagedResponse<BlockedUserResponse> response = blockService.getBlockedUsers(principal.userId(), pageable);
        return ResponseEntity.ok(response);
    }
}
