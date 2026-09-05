package com.wedo.backend.auth.controller;

import com.wedo.backend.auth.dto.CompleteProfileRequest;
import com.wedo.backend.auth.dto.CompleteProfileResponse;
import com.wedo.backend.auth.dto.LoginRequest;
import com.wedo.backend.auth.dto.LoginResponse;
import com.wedo.backend.auth.dto.RefreshTokenRequest;
import com.wedo.backend.auth.dto.RefreshTokenResponse;
import com.wedo.backend.auth.dto.RegisterRequest;
import com.wedo.backend.auth.dto.RegisterResponse;
import com.wedo.backend.auth.dto.ResendVerificationRequest;
import com.wedo.backend.auth.dto.ResendVerificationResponse;
import com.wedo.backend.auth.dto.UsernameAvailabilityResponse;
import com.wedo.backend.auth.dto.VerifyEmailRequest;
import com.wedo.backend.auth.dto.VerifyEmailResponse;
import com.wedo.backend.auth.service.AuthService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/register")
    public ResponseEntity<RegisterResponse> register(@Valid @RequestBody RegisterRequest request) {
        RegisterResponse response = authService.register(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @PostMapping("/verify-email")
    public ResponseEntity<VerifyEmailResponse> verifyEmail(@Valid @RequestBody VerifyEmailRequest request) {
        VerifyEmailResponse response = authService.verifyEmail(request);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/resend-verification")
    public ResponseEntity<ResendVerificationResponse> resendVerification(@Valid @RequestBody ResendVerificationRequest request) {
        ResendVerificationResponse response = authService.resendVerification(request);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/usernames/{username}/availability")
    public ResponseEntity<UsernameAvailabilityResponse> checkUsernameAvailability(
            @PathVariable
            @Size(min = 3, max = 30, message = "Username must be between 3 and 30 characters")
            @Pattern(
                    regexp = "^[a-zA-Z0-9_]{3,30}$",
                    message = "Username must contain only letters, numbers, and underscores"
            )
            String username
    ) {
        UsernameAvailabilityResponse response = authService.checkUsernameAvailability(username);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/complete-profile")
    public ResponseEntity<CompleteProfileResponse> completeProfile(
            @Valid @RequestBody CompleteProfileRequest request
    ) {
        CompleteProfileResponse response = authService.completeProfile(request);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/login")
    public ResponseEntity<LoginResponse> login(@Valid @RequestBody LoginRequest request) {
        LoginResponse response = authService.login(request);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/refresh")
    public ResponseEntity<RefreshTokenResponse> refresh(@Valid @RequestBody RefreshTokenRequest request) {
        RefreshTokenResponse response = authService.refreshToken(request);
        return ResponseEntity.ok(response);
    }
}
