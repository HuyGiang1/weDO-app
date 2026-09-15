package com.wedo.backend.group.controller;

import com.wedo.backend.group.dto.CreateInviteLinkRequest;
import com.wedo.backend.group.dto.GroupInviteSummaryResponse;
import com.wedo.backend.group.dto.InviteLinkResponse;
import com.wedo.backend.group.dto.JoinRequestResponse;
import com.wedo.backend.group.service.GroupAdmissionService;
import com.wedo.backend.security.AuthenticatedUserPrincipal;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@Validated
public class GroupInviteLinkController {

    private final GroupAdmissionService admissionService;

    public GroupInviteLinkController(GroupAdmissionService admissionService) {
        this.admissionService = admissionService;
    }

    @PostMapping("/api/v1/groups/{groupId}/invite-links")
    public ResponseEntity<InviteLinkResponse> createInviteLink(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID groupId,
            @Valid @RequestBody CreateInviteLinkRequest request
    ) {
        InviteLinkResponse response = admissionService.createInviteLink(groupId, principal.userId(), request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @GetMapping("/api/v1/groups/{groupId}/invite-links")
    public ResponseEntity<List<InviteLinkResponse>> getInviteLinks(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID groupId
    ) {
        List<InviteLinkResponse> response = admissionService.getInviteLinks(groupId, principal.userId());
        return ResponseEntity.ok(response);
    }

    @PostMapping("/api/v1/group-invite-links/{id}/revoke")
    public ResponseEntity<Void> revokeInviteLink(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID id
    ) {
        admissionService.revokeInviteLink(id, principal.userId());
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/api/v1/group-invites/{inviteCode}")
    public ResponseEntity<GroupInviteSummaryResponse> resolveInviteCode(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable String inviteCode
    ) {
        GroupInviteSummaryResponse response = admissionService.resolveInviteCode(inviteCode, principal.userId());
        return ResponseEntity.ok(response);
    }

    @PostMapping("/api/v1/group-invites/{inviteCode}/join")
    public ResponseEntity<?> joinViaInviteCode(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable String inviteCode
    ) {
        Object result = admissionService.joinViaInviteCode(inviteCode, principal.userId());
        if (result instanceof JoinRequestResponse joinRequestResponse) {
            return ResponseEntity.status(HttpStatus.CREATED).body(joinRequestResponse);
        }
        return ResponseEntity.ok().build();
    }
}
