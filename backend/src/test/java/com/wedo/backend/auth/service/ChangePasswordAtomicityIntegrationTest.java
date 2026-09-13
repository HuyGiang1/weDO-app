package com.wedo.backend.auth.service;

import com.wedo.backend.auth.dto.ChangePasswordRequest;
import com.wedo.backend.auth.repository.RefreshSessionRepository;
import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.user.entity.UserCredentialEntity;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserCredentialRepository;
import com.wedo.backend.user.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;

class ChangePasswordAtomicityIntegrationTest extends AbstractPostgresIntegrationTest {

    @Autowired private AuthService authService;
    @Autowired private UserRepository userRepository;
    @Autowired private UserCredentialRepository credentialRepository;
    @Autowired private PasswordEncoder passwordEncoder;

    @MockitoBean private RefreshSessionRepository refreshSessionRepository;

    @Test
    void sessionRevocationFailure_rollsBackTheCredentialMutation() {
        UUID userId = UUID.randomUUID();
        Instant now = Instant.now();
        String currentPassword = "OldPassword123!";
        userRepository.saveAndFlush(new UserEntity(
                userId, "atomic." + userId + "@example.com", "atomic_" + userId,
                "Atomic", UserStatus.ACTIVE, now, now));
        credentialRepository.saveAndFlush(new UserCredentialEntity(
                userId, passwordEncoder.encode(currentPassword), 3, now.plusSeconds(300), now, now, now));
        UserCredentialEntity before = credentialRepository.findById(userId).orElseThrow();
        CredentialSnapshot snapshot = new CredentialSnapshot(
                before.getPasswordHash(), before.getFailedAttempts(), before.getLockedUntil(),
                before.getPasswordChangedAt(), before.getUpdatedAt());

        doThrow(new DataAccessResourceFailureException("simulated session persistence failure"))
                .when(refreshSessionRepository).revokeAllActiveByUserId(any(), any());

        assertThatThrownBy(() -> authService.changePassword(
                userId, new ChangePasswordRequest(currentPassword, "NewPassword456!")))
                .isInstanceOf(DataAccessResourceFailureException.class);

        UserCredentialEntity after = credentialRepository.findById(userId).orElseThrow();
        assertThat(new CredentialSnapshot(
                after.getPasswordHash(), after.getFailedAttempts(), after.getLockedUntil(),
                after.getPasswordChangedAt(), after.getUpdatedAt())).isEqualTo(snapshot);
        assertThat(passwordEncoder.matches(currentPassword, after.getPasswordHash())).isTrue();
        assertThat(passwordEncoder.matches("NewPassword456!", after.getPasswordHash())).isFalse();
    }

    private record CredentialSnapshot(
            String passwordHash,
            int failedAttempts,
            Instant lockedUntil,
            Instant passwordChangedAt,
            Instant updatedAt
    ) {
    }
}
