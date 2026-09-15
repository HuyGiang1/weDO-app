package com.wedo.backend.group.controller;

import com.wedo.backend.common.dto.PagedResponse;
import com.wedo.backend.group.dto.JoinRequestResponse;
import com.wedo.backend.group.service.GroupAdmissionService;
import com.wedo.backend.security.AuthenticatedUserPrincipal;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@Validated
public class GroupJoinRequestController {

    private final GroupAdmissionService admissionService;

    public GroupJoinRequestController(GroupAdmissionService admissionService) {
        this.admissionService = admissionService;
    }

    @GetMapping("/api/v1/groups/{groupId}/join-requests")
    public ResponseEntity<PagedResponse<JoinRequestResponse>> getJoinRequests(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID groupId,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size
    ) {
        PagedResponse<JoinRequestResponse> response = admissionService.getJoinRequests(groupId, principal.userId(), page, size);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/api/v1/group-join-requests/{requestId}/approve")
    public ResponseEntity<Void> approveJoinRequest(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID requestId
    ) {
        admissionService.approveJoinRequest(requestId, principal.userId());
        return ResponseEntity.ok().build();
    }

    @PostMapping("/api/v1/group-join-requests/{requestId}/reject")
    public ResponseEntity<Void> rejectJoinRequest(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID requestId
    ) {
        admissionService.rejectJoinRequest(requestId, principal.userId());
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/api/v1/group-join-requests/{requestId}/cancel")
    public ResponseEntity<Void> cancelJoinRequest(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID requestId
    ) {
        admissionService.cancelJoinRequest(requestId, principal.userId());
        return ResponseEntity.noContent().build();
    }
}
