package com.wedo.backend.user.controller;

import com.wedo.backend.auth.security.ProfileCompletionTokenService;
import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.security.jwt.JwtService;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.UUID;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
class UserControllerTest extends AbstractPostgresIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private ProfileCompletionTokenService profileCompletionTokenService;

    @Autowired
    private UserRepository userRepository;

    @Test
    @DisplayName("ACTIVE user with valid access JWT should return 200 with exact fields and no sensitive/internal fields")
    void getMyProfile_activeUser_shouldReturn200WithExactFields() throws Exception {
        UUID userId = UUID.randomUUID();
        UserEntity user = new UserEntity(
                userId,
                "active." + userId + "@example.com",
                "active" + userId.toString().substring(0, 8),
                "Active Display",
                UserStatus.ACTIVE,
                Instant.now(),
                Instant.now()
        );
        user.setPhone("+84987654321");
        user.setAvatarStorageKey("avatars/user-123.jpg");
        user.setBio("Hello, I am active user!");
        user.setEmailVerifiedAt(Instant.now());
        userRepository.save(user);

        String token = jwtService.generateAccessToken(userId);

        mockMvc.perform(get("/api/v1/me")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.id").value(userId.toString()))
                .andExpect(jsonPath("$.username").value(user.getUsername()))
                .andExpect(jsonPath("$.email").value(user.getEmail()))
                .andExpect(jsonPath("$.phone").value("+84987654321"))
                .andExpect(jsonPath("$.displayName").value("Active Display"))
                .andExpect(jsonPath("$.avatarStorageKey").value("avatars/user-123.jpg"))
                .andExpect(jsonPath("$.bio").value("Hello, I am active user!"))
                .andExpect(jsonPath("$.status").value("ACTIVE"))
                .andExpect(jsonPath("$.emailVerified").value(true))
                .andExpect(jsonPath("$.createdAt").doesNotExist())
                .andExpect(jsonPath("$.emailVerifiedAt").doesNotExist())
                .andExpect(jsonPath("$.passwordHash").doesNotExist())
                .andExpect(jsonPath("$.failedAttempts").doesNotExist())
                .andExpect(jsonPath("$.lockedUntil").doesNotExist())
                .andExpect(jsonPath("$.credentials").doesNotExist())
                .andExpect(jsonPath("$.refreshSessions").doesNotExist());
    }

    @Test
    @DisplayName("SUSPENDED user should return 403 ACCOUNT_SUSPENDED")
    void getMyProfile_suspendedUser_shouldReturn403AccountSuspended() throws Exception {
        UUID userId = UUID.randomUUID();
        UserEntity user = new UserEntity(
                userId,
                "suspended." + userId + "@example.com",
                "susp" + userId.toString().substring(0, 8),
                "Suspended User",
                UserStatus.SUSPENDED,
                Instant.now(),
                Instant.now()
        );
        userRepository.save(user);

        String token = jwtService.generateAccessToken(userId);

        mockMvc.perform(get("/api/v1/me")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.status").value(403))
                .andExpect(jsonPath("$.code").value("ACCOUNT_SUSPENDED"))
                .andExpect(jsonPath("$.message").value("Account has been suspended."));
    }

    @Test
    @DisplayName("DEACTIVATED user should return 403 ACCOUNT_DEACTIVATED")
    void getMyProfile_deactivatedUser_shouldReturn403AccountDeactivated() throws Exception {
        UUID userId = UUID.randomUUID();
        UserEntity user = new UserEntity(
                userId,
                "deact." + userId + "@example.com",
                "deact" + userId.toString().substring(0, 8),
                "Deactivated User",
                UserStatus.DEACTIVATED,
                Instant.now(),
                Instant.now()
        );
        userRepository.save(user);

        String token = jwtService.generateAccessToken(userId);

        mockMvc.perform(get("/api/v1/me")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.status").value(403))
                .andExpect(jsonPath("$.code").value("ACCOUNT_DEACTIVATED"))
                .andExpect(jsonPath("$.message").value("Account has been deactivated."));
    }

    @Test
    @DisplayName("PENDING_VERIFICATION user should return 403 EMAIL_NOT_VERIFIED")
    void getMyProfile_pendingVerificationUser_shouldReturn403EmailNotVerified() throws Exception {
        UUID userId = UUID.randomUUID();
        UserEntity user = new UserEntity(
                userId,
                "pending." + userId + "@example.com",
                "pending" + userId.toString().substring(0, 8),
                "Pending User",
                UserStatus.PENDING_VERIFICATION,
                Instant.now(),
                Instant.now()
        );
        userRepository.save(user);

        String token = jwtService.generateAccessToken(userId);

        mockMvc.perform(get("/api/v1/me")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.status").value(403))
                .andExpect(jsonPath("$.code").value("EMAIL_NOT_VERIFIED"))
                .andExpect(jsonPath("$.message").value("Email address has not been verified."));
    }

    @Test
    @DisplayName("valid JWT but user not found in DB should return 401 AUTH_TOKEN_INVALID")
    void getMyProfile_validJwtUserNotFound_shouldReturn401AuthTokenInvalid() throws Exception {
        UUID nonExistentUserId = UUID.randomUUID();
        String token = jwtService.generateAccessToken(nonExistentUserId);

        mockMvc.perform(get("/api/v1/me")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("AUTH_TOKEN_INVALID"))
                .andExpect(jsonPath("$.message").value("Invalid authentication token."));
    }

    @Test
    @DisplayName("unauthenticated request to /api/v1/me should return 401 UNAUTHORIZED")
    void getMyProfile_unauthenticated_shouldReturn401Unauthorized() throws Exception {
        mockMvc.perform(get("/api/v1/me"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"))
                .andExpect(jsonPath("$.message").value("Authentication is required."));
    }

    @Test
    @DisplayName("profileCompletionToken presented as Bearer token cannot authenticate GET /api/v1/me due to distinct signing key verification failure")
    void profileCompletionToken_cannotAuthenticateGetMyProfile() throws Exception {
        UUID userId = UUID.randomUUID();
        UserEntity user = new UserEntity(
                userId,
                "tokensep." + userId + "@example.com",
                "tokensep" + userId.toString().substring(0, 8),
                "Token Sep User",
                UserStatus.ACTIVE,
                Instant.now(),
                Instant.now()
        );
        userRepository.save(user);

        String profileToken = profileCompletionTokenService.generate(userId);

        mockMvc.perform(get("/api/v1/me")
                        .header("Authorization", "Bearer " + profileToken))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("AUTH_TOKEN_INVALID"))
                .andExpect(jsonPath("$.message").value("Invalid authentication token."));
    }

    @Test
    @DisplayName("PATCH /api/v1/me/profile updates only allow-listed self-profile fields")
    void updateMyProfile_activeUser_shouldUpdateAllowedFields() throws Exception {
        UUID userId = UUID.randomUUID();
        UserEntity user = new UserEntity(userId, "update." + userId + "@example.com", "update" + userId.toString().substring(0, 8), "Before", UserStatus.ACTIVE, Instant.now(), Instant.now());
        user.setBio("Before bio");
        userRepository.save(user);

        mockMvc.perform(patch("/api/v1/me/profile")
                        .header("Authorization", "Bearer " + jwtService.generateAccessToken(userId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"displayName":"  Updated Name  ","bio":"  Updated bio  ","phone":"  +84987654321  ","email":"attacker@example.com","status":"SUSPENDED"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.displayName").value("Updated Name"))
                .andExpect(jsonPath("$.bio").value("Updated bio"))
                .andExpect(jsonPath("$.phone").value("+84987654321"))
                .andExpect(jsonPath("$.email").value(user.getEmail()))
                .andExpect(jsonPath("$.status").value("ACTIVE"));
    }

    @Test
    @DisplayName("PATCH /api/v1/me/profile treats null fields as no-op and blank clearable fields as null")
    void updateMyProfile_patchSemantics_shouldBeApplied() throws Exception {
        UUID userId = UUID.randomUUID();
        UserEntity user = new UserEntity(userId, "clear." + userId + "@example.com", "clear" + userId.toString().substring(0, 8), "Original", UserStatus.ACTIVE, Instant.now(), Instant.now());
        user.setBio("Bio");
        user.setPhone("Phone");
        user.setAvatarStorageKey("avatar/key");
        userRepository.save(user);

        mockMvc.perform(patch("/api/v1/me/profile")
                        .header("Authorization", "Bearer " + jwtService.generateAccessToken(userId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"displayName\":null,\"bio\":\"   \",\"phone\":\" \",\"avatarStorageKey\":\"  \"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.displayName").value("Original"))
                .andExpect(jsonPath("$.bio").doesNotExist())
                .andExpect(jsonPath("$.phone").doesNotExist())
                .andExpect(jsonPath("$.avatarStorageKey").doesNotExist());
    }
}
