package com.wedo.backend.user.controller;

import com.wedo.backend.auth.dto.ChangePasswordRequest;
import com.wedo.backend.auth.service.AuthService;
import com.wedo.backend.security.AuthenticatedUserPrincipal;
import com.wedo.backend.user.dto.MyProfileResponse;
import com.wedo.backend.user.dto.PrivacySettingsResponse;
import com.wedo.backend.user.dto.UpdateProfileRequest;
import com.wedo.backend.user.dto.UpdatePrivacySettingsRequest;
import com.wedo.backend.user.dto.UpdateUsernameRequest;
import com.wedo.backend.user.dto.UserPublicProfileResponse;
import com.wedo.backend.user.service.UserPrivacySettingsService;
import com.wedo.backend.user.service.UserService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1")
public class UserController {

    private final UserService userService;
    private final UserPrivacySettingsService userPrivacySettingsService;
    private final AuthService authService;

    public UserController(
            UserService userService,
            UserPrivacySettingsService userPrivacySettingsService,
            AuthService authService
    ) {
        this.userService = userService;
        this.userPrivacySettingsService = userPrivacySettingsService;
        this.authService = authService;
    }

    @GetMapping("/me")
    public ResponseEntity<MyProfileResponse> getMyProfile(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal
    ) {
        MyProfileResponse response = userService.getCurrentUser(principal.userId());
        return ResponseEntity.ok(response);
    }

    @PatchMapping("/me/profile")
    public ResponseEntity<MyProfileResponse> updateMyProfile(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @Valid @RequestBody UpdateProfileRequest request
    ) {
        MyProfileResponse response = userService.updateProfile(principal.userId(), request);
        return ResponseEntity.ok(response);
    }

    @PatchMapping("/me/username")
    public ResponseEntity<MyProfileResponse> updateMyUsername(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @Valid @RequestBody UpdateUsernameRequest request
    ) {
        MyProfileResponse response = userService.updateUsername(principal.userId(), request);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/me/change-password")
    public ResponseEntity<Void> changePassword(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @Valid @RequestBody ChangePasswordRequest request
    ) {
        authService.changePassword(principal.userId(), request);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/users/{userId}")
    public ResponseEntity<UserPublicProfileResponse> getPublicProfile(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID userId
    ) {
        return ResponseEntity.ok(userService.getPublicProfile(principal.userId(), userId));
    }

    @GetMapping("/me/privacy")
    public ResponseEntity<PrivacySettingsResponse> getMyPrivacySettings(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal
    ) {
        return ResponseEntity.ok(userPrivacySettingsService.getCurrentUserPrivacySettings(principal.userId()));
    }

    @PatchMapping("/me/privacy")
    public ResponseEntity<PrivacySettingsResponse> updateMyPrivacySettings(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @Valid @RequestBody UpdatePrivacySettingsRequest request
    ) {
        return ResponseEntity.ok(userPrivacySettingsService.updateCurrentUserPrivacySettings(principal.userId(), request));
    }
}
