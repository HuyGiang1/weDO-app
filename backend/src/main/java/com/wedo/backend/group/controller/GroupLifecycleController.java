package com.wedo.backend.group.controller;

import com.wedo.backend.group.service.GroupLifecycleService;
import com.wedo.backend.security.AuthenticatedUserPrincipal;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@Validated
public class GroupLifecycleController {

    private final GroupLifecycleService lifecycleService;

    public GroupLifecycleController(GroupLifecycleService lifecycleService) {
        this.lifecycleService = lifecycleService;
    }

    @PostMapping("/api/v1/groups/{groupId}/archive")
    public ResponseEntity<Void> archiveGroup(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID groupId
    ) {
        lifecycleService.archiveGroup(groupId, principal.userId());
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/api/v1/groups/{groupId}/restore")
    public ResponseEntity<Void> restoreGroup(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID groupId
    ) {
        lifecycleService.restoreGroup(groupId, principal.userId());
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/api/v1/groups/{groupId}")
    public ResponseEntity<Void> deleteGroup(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID groupId
    ) {
        lifecycleService.deleteGroup(groupId, principal.userId());
        return ResponseEntity.noContent().build();
    }
}
