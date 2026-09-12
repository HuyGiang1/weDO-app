package com.wedo.backend.user.controller;

import com.wedo.backend.security.AuthenticatedUserPrincipal;
import com.wedo.backend.user.dto.MyProfileResponse;
import com.wedo.backend.user.dto.UpdateProfileRequest;
import com.wedo.backend.user.dto.UpdateUsernameRequest;
import com.wedo.backend.user.service.UserService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
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
}
