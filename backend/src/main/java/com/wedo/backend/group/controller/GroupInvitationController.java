package com.wedo.backend.group.controller;

import com.wedo.backend.common.dto.PagedResponse;
import com.wedo.backend.group.dto.CreateInvitationRequest;
import com.wedo.backend.group.dto.GroupInvitationResponse;
import com.wedo.backend.group.entity.GroupInvitationStatus;
import com.wedo.backend.group.service.GroupAdmissionService;
import com.wedo.backend.security.AuthenticatedUserPrincipal;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Pattern;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@Validated
public class GroupInvitationController {

    private final GroupAdmissionService admissionService;

    public GroupInvitationController(GroupAdmissionService admissionService) {
        this.admissionService = admissionService;
    }

    @PostMapping("/api/v1/groups/{groupId}/invitations")
    public ResponseEntity<GroupInvitationResponse> createInvitation(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID groupId,
            @Valid @RequestBody CreateInvitationRequest request
    ) {
        GroupInvitationResponse response = admissionService.createInvitation(groupId, principal.userId(), request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @GetMapping("/api/v1/me/group-invitations")
    public ResponseEntity<PagedResponse<GroupInvitationResponse>> getMyInvitations(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size,
            @RequestParam(defaultValue = "PENDING") @Pattern(regexp = "PENDING|ACCEPTED|DECLINED|CANCELLED") String status
    ) {
        GroupInvitationStatus invitationStatus = GroupInvitationStatus.valueOf(status);
        PagedResponse<GroupInvitationResponse> response = admissionService.getMyInvitations(principal.userId(), page, size, invitationStatus);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/api/v1/group-invitations/{id}/accept")
    public ResponseEntity<Void> acceptInvitation(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID id
    ) {
        admissionService.acceptInvitation(id, principal.userId());
        return ResponseEntity.ok().build();
    }

    @PostMapping("/api/v1/group-invitations/{id}/decline")
    public ResponseEntity<Void> declineInvitation(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID id
    ) {
        admissionService.declineInvitation(id, principal.userId());
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/api/v1/group-invitations/{id}/cancel")
    public ResponseEntity<Void> cancelInvitation(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID id
    ) {
        admissionService.cancelInvitation(id, principal.userId());
        return ResponseEntity.noContent().build();
    }
}
