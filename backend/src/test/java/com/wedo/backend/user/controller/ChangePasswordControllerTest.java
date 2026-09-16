package com.wedo.backend.user.controller;

import com.wedo.backend.auth.dto.ChangePasswordRequest;
import com.wedo.backend.auth.dto.RefreshTokenRequest;
import com.wedo.backend.auth.entity.RefreshSessionEntity;
import com.wedo.backend.auth.repository.RefreshSessionRepository;
import com.wedo.backend.auth.security.RefreshTokenService;
import com.wedo.backend.auth.service.AuthService;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.security.jwt.JwtService;
import com.wedo.backend.user.entity.UserCredentialEntity;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserCredentialRepository;
import com.wedo.backend.user.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
class ChangePasswordControllerTest extends AbstractPostgresIntegrationTest {

    @Autowired private MockMvc mockMvc;
    @Autowired private JwtService jwtService;
    @Autowired private PasswordEncoder passwordEncoder;
    @Autowired private AuthService authService;
    @Autowired private UserRepository userRepository;
    @Autowired private UserCredentialRepository credentialRepository;
    @Autowired private RefreshSessionRepository refreshSessionRepository;

    @Test
    void activeLockedUser_changesPasswordAndRevokesEveryActiveRefreshSession() throws Exception {
        UUID userId = createUser(UserStatus.ACTIVE, "OldPassword123!");
        UserCredentialEntity before = credentialRepository.findById(userId).orElseThrow();
        before.setFailedAttempts(4);
        before.setLockedUntil(Instant.now().plus(10, ChronoUnit.MINUTES));
        before.setPasswordChangedAt(Instant.now().minus(1, ChronoUnit.DAYS));
        before.setUpdatedAt(Instant.now().minus(1, ChronoUnit.DAYS));
        credentialRepository.saveAndFlush(before);
        String currentDeviceToken = createActiveRefreshSession(userId);
        createActiveRefreshSession(userId);
        Instant alreadyRevokedAt = Instant.now().minus(1, ChronoUnit.HOURS).truncatedTo(ChronoUnit.MICROS);
        RefreshSessionEntity alreadyRevoked = createSession(userId, alreadyRevokedAt);
        String oldHash = before.getPasswordHash();
        Instant oldPasswordChangedAt = before.getPasswordChangedAt();
        Instant oldUpdatedAt = before.getUpdatedAt();

        mockMvc.perform(post("/api/v1/me/change-password")
                        .header("Authorization", bearer(userId))
                        .contentType("application/json")
                        .content("{\"currentPassword\":\"OldPassword123!\",\"newPassword\":\"NewPassword456!\"}"))
                .andExpect(status().isNoContent())
                .andExpect(content().string(""));

        UserCredentialEntity after = credentialRepository.findById(userId).orElseThrow();
        assertThat(after.getPasswordHash()).isNotEqualTo(oldHash);
        assertThat(passwordEncoder.matches("NewPassword456!", after.getPasswordHash())).isTrue();
        assertThat(passwordEncoder.matches("OldPassword123!", after.getPasswordHash())).isFalse();
        assertThat(after.getPasswordChangedAt()).isAfter(oldPasswordChangedAt);
        assertThat(after.getUpdatedAt()).isAfter(oldUpdatedAt);
        assertThat(after.getFailedAttempts()).isZero();
        assertThat(after.getLockedUntil()).isNull();
        assertThat(refreshSessionRepository.findAll().stream()
                .filter(session -> session.getUserId().equals(userId))
                .filter(session -> !session.getId().equals(alreadyRevoked.getId()))
                .allMatch(session -> session.getRevokedAt() != null)).isTrue();
        assertThat(refreshSessionRepository.findById(alreadyRevoked.getId()).orElseThrow().getRevokedAt())
                .isEqualTo(alreadyRevokedAt);
        assertThatThrownBy(() -> authService.refreshToken(new RefreshTokenRequest(currentDeviceToken)))
                .isInstanceOf(BusinessException.class)
                .satisfies(exception -> assertThat(((BusinessException) exception).errorCode())
                        .isEqualTo(ErrorCode.REFRESH_TOKEN_INVALID));
    }

    @Test
    void wrongCurrentPasswordAndSameAsOld_leaveCredentialAndSessionsUntouched() throws Exception {
        UUID userId = createUser(UserStatus.ACTIVE, "OldPassword123!");
        UserCredentialEntity credential = credentialRepository.findById(userId).orElseThrow();
        credential.setFailedAttempts(2);
        credential.setLockedUntil(Instant.now().plus(5, ChronoUnit.MINUTES));
        credentialRepository.saveAndFlush(credential);
        String refreshToken = createActiveRefreshSession(userId);
        CredentialSnapshot before = snapshot(userId);

        mockMvc.perform(post("/api/v1/me/change-password")
                        .header("Authorization", bearer(userId))
                        .contentType("application/json")
                        .content("{\"currentPassword\":\"WrongPassword123!\",\"newPassword\":\"NewPassword456!\"}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("AUTH_INVALID_CREDENTIALS"));
        assertSnapshotUnchanged(before, userId, refreshToken);

        mockMvc.perform(post("/api/v1/me/change-password")
                        .header("Authorization", bearer(userId))
                        .contentType("application/json")
                        .content("{\"currentPassword\":\"OldPassword123!\",\"newPassword\":\"OldPassword123!\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
        assertSnapshotUnchanged(before, userId, refreshToken);
    }

    @Test
    void validatesNewPasswordAndProtectsCallerIdentity() throws Exception {
        UUID userId = createUser(UserStatus.ACTIVE, "OldPassword123!");
        UUID otherUserId = createUser(UserStatus.ACTIVE, "OtherPassword123!");
        assertValidationFailure(userId, "", "Password must be between 8 and 72 characters");
        assertValidationFailure(userId, "short", "Password must be between 8 and 72 characters");
        assertValidationFailure(userId, "a".repeat(73), "Password must be between 8 and 72 characters");
        String oversizedUtf8 = "\u1E7F".repeat(25);
        assertThat(oversizedUtf8.getBytes(StandardCharsets.UTF_8)).hasSize(75);
        assertValidationFailure(
                userId,
                oversizedUtf8,
                "newPasswordByteLengthValid",
                "Password must not exceed 72 bytes in UTF-8 encoding"
        );

        mockMvc.perform(post("/api/v1/me/change-password")
                        .header("Authorization", bearer(userId))
                        .contentType("application/json")
                        .content("{\"currentPassword\":\"OldPassword123!\",\"newPassword\":\"NewPassword456!\",\"userId\":\"" + otherUserId + "\"}"))
                .andExpect(status().isNoContent());
        assertThat(passwordEncoder.matches("OtherPassword123!", credentialRepository.findById(otherUserId).orElseThrow().getPasswordHash())).isTrue();
    }

    @Test
    void protectedEndpointEnforcesActiveStatusAndMissingCredentialIsInternal() throws Exception {
        UUID activeUserId = createUser(UserStatus.ACTIVE, "OldPassword123!");
        mockMvc.perform(post("/api/v1/me/change-password").contentType("application/json").content("{}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));

        assertInactiveCaller(UserStatus.PENDING_VERIFICATION, "EMAIL_NOT_VERIFIED");
        assertInactiveCaller(UserStatus.SUSPENDED, "ACCOUNT_SUSPENDED");
        assertInactiveCaller(UserStatus.DEACTIVATED, "ACCOUNT_DEACTIVATED");

        UUID missingCredentialUserId = createUserWithoutCredential(UserStatus.ACTIVE);
        mockMvc.perform(post("/api/v1/me/change-password")
                        .header("Authorization", bearer(missingCredentialUserId))
                        .contentType("application/json")
                        .content("{\"currentPassword\":\"OldPassword123!\",\"newPassword\":\"NewPassword456!\"}"))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.code").value("INTERNAL_SERVER_ERROR"));

        assertThat(activeUserId).isNotNull();
    }

    private void assertValidationFailure(UUID userId, String newPassword, String message) throws Exception {
        assertValidationFailure(userId, newPassword, "newPassword", message);
    }

    private void assertValidationFailure(UUID userId, String newPassword, String field, String message) throws Exception {
        mockMvc.perform(post("/api/v1/me/change-password")
                        .header("Authorization", bearer(userId))
                        .contentType("application/json")
                        .content("{\"currentPassword\":\"OldPassword123!\",\"newPassword\":\"" + newPassword + "\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.errors." + field).exists());
    }

    private void assertInactiveCaller(UserStatus status, String errorCode) throws Exception {
        UUID userId = createUser(status, "OldPassword123!");
        mockMvc.perform(post("/api/v1/me/change-password")
                        .header("Authorization", bearer(userId))
                        .contentType("application/json")
                        .content("{\"currentPassword\":\"OldPassword123!\",\"newPassword\":\"NewPassword456!\"}"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value(errorCode));
    }

    private void assertSnapshotUnchanged(CredentialSnapshot before, UUID userId, String refreshToken) {
        assertThat(snapshot(userId)).isEqualTo(before);
        RefreshSessionEntity session = refreshSessionRepository.findByTokenHash(RefreshTokenService.hashToken(refreshToken)).orElseThrow();
        assertThat(session.getRevokedAt()).isNull();
    }

    private CredentialSnapshot snapshot(UUID userId) {
        UserCredentialEntity credential = credentialRepository.findById(userId).orElseThrow();
        return new CredentialSnapshot(
                credential.getPasswordHash(),
                credential.getPasswordChangedAt(),
                credential.getUpdatedAt(),
                credential.getFailedAttempts(),
                credential.getLockedUntil()
        );
    }

    private UUID createUser(UserStatus status, String password) {
        UUID id = UUID.randomUUID();
        Instant now = Instant.now();
        userRepository.saveAndFlush(new UserEntity(id, "password." + id + "@example.com", "password_" + id, "Password", status, now, now));
        credentialRepository.saveAndFlush(new UserCredentialEntity(id, passwordEncoder.encode(password), 0, null, now, now, now));
        return id;
    }

    private UUID createUserWithoutCredential(UserStatus status) {
        UUID id = UUID.randomUUID();
        Instant now = Instant.now();
        userRepository.saveAndFlush(new UserEntity(id, "missing." + id + "@example.com", "missing_" + id, "Missing", status, now, now));
        return id;
    }

    private String createActiveRefreshSession(UUID userId) {
        String rawToken = "refresh-" + UUID.randomUUID();
        createSession(userId, null, rawToken);
        return rawToken;
    }

    private RefreshSessionEntity createSession(UUID userId, Instant revokedAt) {
        return createSession(userId, revokedAt, "refresh-" + UUID.randomUUID());
    }

    private RefreshSessionEntity createSession(UUID userId, Instant revokedAt, String rawToken) {
        Instant now = Instant.now();
        return refreshSessionRepository.saveAndFlush(new RefreshSessionEntity(
                UUID.randomUUID(), userId, RefreshTokenService.hashToken(rawToken), now.plus(1, ChronoUnit.DAYS),
                revokedAt, null, null, null, now, now.plus(30, ChronoUnit.DAYS)
        ));
    }

    private String bearer(UUID userId) {
        return "Bearer " + jwtService.generateAccessToken(userId);
    }

    private record CredentialSnapshot(String passwordHash, Instant passwordChangedAt, Instant updatedAt, int failedAttempts, Instant lockedUntil) {
    }
}
