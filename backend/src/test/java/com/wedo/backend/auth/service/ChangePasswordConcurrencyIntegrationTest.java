package com.wedo.backend.auth.service;

import com.wedo.backend.auth.dto.ChangePasswordRequest;
import com.wedo.backend.auth.entity.RefreshSessionEntity;
import com.wedo.backend.auth.repository.RefreshSessionRepository;
import com.wedo.backend.auth.security.RefreshTokenService;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.user.entity.UserCredentialEntity;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserCredentialRepository;
import com.wedo.backend.user.repository.UserRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class ChangePasswordConcurrencyIntegrationTest extends AbstractPostgresIntegrationTest {

    @Autowired private AuthService authService;
    @Autowired private UserRepository userRepository;
    @Autowired private UserCredentialRepository credentialRepository;
    @Autowired private RefreshSessionRepository refreshSessionRepository;
    @Autowired private PasswordEncoder passwordEncoder;

    @Test
    @DisplayName("two independent password changes with one old password allow exactly one winner")
    void concurrentChanges_serializeOnCredentialAndLeaveNoActiveRefreshSession() throws Exception {
        UUID userId = createActiveUser("OldPassword123!");
        createActiveRefreshSession(userId);
        createActiveRefreshSession(userId);
        CountDownLatch ready = new CountDownLatch(2);
        CountDownLatch start = new CountDownLatch(1);
        ExecutorService executor = Executors.newFixedThreadPool(2);

        try {
            Future<Outcome> first = executor.submit(() -> changeAfterStart(
                    userId, "OldPassword123!", "WinnerPassword111!", ready, start));
            Future<Outcome> second = executor.submit(() -> changeAfterStart(
                    userId, "OldPassword123!", "WinnerPassword222!", ready, start));
            assertTrue(ready.await(5, TimeUnit.SECONDS));
            start.countDown();

            List<Outcome> outcomes = List.of(first.get(15, TimeUnit.SECONDS), second.get(15, TimeUnit.SECONDS));
            assertEquals(1, outcomes.stream().filter(Outcome::success).count());
            assertEquals(1, outcomes.stream()
                    .filter(outcome -> outcome.errorCode() == ErrorCode.AUTH_INVALID_CREDENTIALS).count());

            UserCredentialEntity credential = credentialRepository.findById(userId).orElseThrow();
            assertTrue(passwordEncoder.matches("WinnerPassword111!", credential.getPasswordHash())
                    || passwordEncoder.matches("WinnerPassword222!", credential.getPasswordHash()));
            assertEquals(0, credential.getFailedAttempts());
            assertTrue(refreshSessionRepository.findAll().stream()
                    .filter(session -> session.getUserId().equals(userId))
                    .allMatch(session -> session.getRevokedAt() != null));
        } finally {
            executor.shutdownNow();
        }
    }

    private Outcome changeAfterStart(
            UUID userId,
            String currentPassword,
            String newPassword,
            CountDownLatch ready,
            CountDownLatch start
    ) {
        ready.countDown();
        try {
            if (!start.await(5, TimeUnit.SECONDS)) {
                throw new IllegalStateException("Concurrent password change did not start");
            }
            authService.changePassword(userId, new ChangePasswordRequest(currentPassword, newPassword));
            return new Outcome(true, null);
        } catch (BusinessException exception) {
            return new Outcome(false, exception.errorCode());
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Concurrent password change was interrupted", exception);
        }
    }

    private UUID createActiveUser(String password) {
        UUID id = UUID.randomUUID();
        Instant now = Instant.now();
        userRepository.saveAndFlush(new UserEntity(id, "race." + id + "@example.com", "race_" + id, "Race", UserStatus.ACTIVE, now, now));
        credentialRepository.saveAndFlush(new UserCredentialEntity(id, passwordEncoder.encode(password), 0, null, now, now, now));
        return id;
    }

    private void createActiveRefreshSession(UUID userId) {
        Instant now = Instant.now();
        refreshSessionRepository.saveAndFlush(new RefreshSessionEntity(
                UUID.randomUUID(), userId, RefreshTokenService.hashToken("refresh-" + UUID.randomUUID()),
                now.plus(1, ChronoUnit.DAYS), null, null, null, null, now, now.plus(30, ChronoUnit.DAYS)
        ));
    }

    private record Outcome(boolean success, ErrorCode errorCode) {
    }
}
