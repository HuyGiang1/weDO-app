package com.wedo.backend.group.controller;

import com.wedo.backend.common.dto.PagedResponse;
import com.wedo.backend.group.dto.BanMemberRequest;
import com.wedo.backend.group.dto.GroupBanResponse;
import com.wedo.backend.group.service.GroupBanService;
import com.wedo.backend.security.AuthenticatedUserPrincipal;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@Validated
public class GroupBanController {

    private final GroupBanService banService;

    public GroupBanController(GroupBanService banService) {
        this.banService = banService;
    }

    @PostMapping("/api/v1/groups/{groupId}/members/{userId}/ban")
    public ResponseEntity<Void> banMember(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID groupId,
            @PathVariable UUID userId,
            @Valid @RequestBody(required = false) BanMemberRequest request
    ) {
        String reason = request != null ? request.reason() : null;
        banService.banMember(groupId, userId, principal.userId(), reason);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/api/v1/groups/{groupId}/bans")
    public ResponseEntity<PagedResponse<GroupBanResponse>> getBans(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID groupId,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "30") @Min(1) @Max(100) int size
    ) {
        PagedResponse<GroupBanResponse> response = banService.getBans(groupId, principal.userId(), page, size);
        return ResponseEntity.ok(response);
    }

    @DeleteMapping("/api/v1/groups/{groupId}/bans/{userId}")
    public ResponseEntity<Void> unbanMember(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID groupId,
            @PathVariable UUID userId
    ) {
        banService.unbanMember(groupId, userId, principal.userId());
        return ResponseEntity.noContent().build();
    }
}
