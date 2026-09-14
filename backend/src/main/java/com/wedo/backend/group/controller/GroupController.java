package com.wedo.backend.group.controller;

import com.wedo.backend.common.dto.PagedResponse;
import com.wedo.backend.group.dto.CreateGroupRequest;
import com.wedo.backend.group.dto.GroupDetailResponse;
import com.wedo.backend.group.dto.GroupMemberResponse;
import com.wedo.backend.group.dto.GroupResponse;
import com.wedo.backend.group.dto.GroupSummaryResponse;
import com.wedo.backend.group.dto.GroupSettingsResponse;
import com.wedo.backend.group.dto.UpdateGroupRequest;
import com.wedo.backend.group.dto.UpdateGroupSettingsRequest;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.group.service.GroupService;
import com.wedo.backend.security.AuthenticatedUserPrincipal;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.validation.annotation.Validated;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Pattern;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/groups")
@Validated
public class GroupController {

    private final GroupService groupService;

    public GroupController(GroupService groupService) {
        this.groupService = groupService;
    }

    @PostMapping
    public ResponseEntity<GroupResponse> createGroup(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @Valid @RequestBody CreateGroupRequest request
    ) {
        return ResponseEntity.status(HttpStatus.CREATED).body(groupService.createGroup(principal.userId(), request));
    }

    @GetMapping
    public ResponseEntity<PagedResponse<GroupSummaryResponse>> getGroups(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @RequestParam(defaultValue = "0") @Min(value = 0, message = "page must be at least 0") int page,
            @RequestParam(defaultValue = "30") @Min(value = 1, message = "size must be at least 1") @Max(value = 100, message = "size must not exceed 100") int size,
            @RequestParam(defaultValue = "ACTIVE") @Pattern(regexp = "ACTIVE|ARCHIVED", message = "status must be ACTIVE or ARCHIVED") String status
    ) {
        return ResponseEntity.ok(groupService.getGroups(principal.userId(), page, size, GroupStatus.valueOf(status)));
    }

    @GetMapping("/{groupId}")
    public ResponseEntity<GroupDetailResponse> getGroup(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID groupId
    ) {
        return ResponseEntity.ok(groupService.getGroup(groupId, principal.userId()));
    }

    @GetMapping("/{groupId}/members")
    public ResponseEntity<List<GroupMemberResponse>> getMembers(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID groupId
    ) {
        return ResponseEntity.ok(groupService.getMembers(groupId, principal.userId()));
    }

    @GetMapping("/{groupId}/members/{userId}")
    public ResponseEntity<GroupMemberResponse> getMember(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID groupId,
            @PathVariable UUID userId
    ) {
        return ResponseEntity.ok(groupService.getMember(groupId, userId, principal.userId()));
    }

    @PatchMapping("/{groupId}")
    public ResponseEntity<GroupDetailResponse> updateGroup(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID groupId,
            @Valid @RequestBody UpdateGroupRequest request
    ) {
        return ResponseEntity.ok(groupService.updateGroup(groupId, principal.userId(), request));
    }

    @GetMapping("/{groupId}/settings")
    public ResponseEntity<GroupSettingsResponse> getSettings(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID groupId
    ) {
        return ResponseEntity.ok(groupService.getSettings(groupId, principal.userId()));
    }

    @PatchMapping("/{groupId}/settings")
    public ResponseEntity<GroupSettingsResponse> updateSettings(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID groupId,
            @RequestBody UpdateGroupSettingsRequest request
    ) {
        return ResponseEntity.ok(groupService.updateSettings(groupId, principal.userId(), request));
    }
}
