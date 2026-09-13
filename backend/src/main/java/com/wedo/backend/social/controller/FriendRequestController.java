package com.wedo.backend.social.controller;

import com.wedo.backend.common.dto.PagedResponse;
import com.wedo.backend.security.AuthenticatedUserPrincipal;
import com.wedo.backend.social.dto.FriendRequestResponse;
import com.wedo.backend.social.service.FriendRequestService;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1")
public class FriendRequestController {

    private final FriendRequestService friendRequestService;

    public FriendRequestController(FriendRequestService friendRequestService) {
        this.friendRequestService = friendRequestService;
    }

    @PostMapping("/users/{userId}/friend-requests")
    public ResponseEntity<FriendRequestResponse> sendFriendRequest(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable("userId") UUID userId
    ) {
        FriendRequestResponse response = friendRequestService.sendFriendRequest(principal.userId(), userId);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @GetMapping("/me/friend-requests")
    public ResponseEntity<PagedResponse<FriendRequestResponse>> getFriendRequests(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @RequestParam(name = "direction", defaultValue = "received") String direction,
            @PageableDefault(size = 30) Pageable pageable
    ) {
        PagedResponse<FriendRequestResponse> response;
        if ("sent".equalsIgnoreCase(direction)) {
            response = friendRequestService.getSentRequests(principal.userId(), pageable);
        } else {
            response = friendRequestService.getReceivedRequests(principal.userId(), pageable);
        }
        return ResponseEntity.ok(response);
    }

    @PostMapping("/friend-requests/{requestId}/accept")
    public ResponseEntity<FriendRequestResponse> acceptFriendRequest(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable("requestId") UUID requestId
    ) {
        FriendRequestResponse response = friendRequestService.acceptFriendRequest(principal.userId(), requestId);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/friend-requests/{requestId}/decline")
    public ResponseEntity<Void> declineFriendRequest(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable("requestId") UUID requestId
    ) {
        friendRequestService.declineFriendRequest(principal.userId(), requestId);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/friend-requests/{requestId}/cancel")
    public ResponseEntity<Void> cancelFriendRequest(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable("requestId") UUID requestId
    ) {
        friendRequestService.cancelFriendRequest(principal.userId(), requestId);
        return ResponseEntity.noContent().build();
    }
}
