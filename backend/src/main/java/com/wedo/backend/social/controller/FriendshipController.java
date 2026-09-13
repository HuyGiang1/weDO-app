package com.wedo.backend.social.controller;

import com.wedo.backend.common.dto.PagedResponse;
import com.wedo.backend.security.AuthenticatedUserPrincipal;
import com.wedo.backend.social.dto.FriendResponse;
import com.wedo.backend.social.service.FriendshipService;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1")
public class FriendshipController {

    private final FriendshipService friendshipService;

    public FriendshipController(FriendshipService friendshipService) {
        this.friendshipService = friendshipService;
    }

    @GetMapping("/me/friends")
    public ResponseEntity<PagedResponse<FriendResponse>> getFriends(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PageableDefault(size = 30) Pageable pageable
    ) {
        PagedResponse<FriendResponse> response = friendshipService.getFriends(principal.userId(), pageable);
        return ResponseEntity.ok(response);
    }

    @DeleteMapping("/friends/{userId}")
    public ResponseEntity<Void> unfriend(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable("userId") UUID userId
    ) {
        friendshipService.unfriend(principal.userId(), userId);
        return ResponseEntity.noContent().build();
    }
}
