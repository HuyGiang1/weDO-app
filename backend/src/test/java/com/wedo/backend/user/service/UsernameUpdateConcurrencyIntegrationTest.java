package com.wedo.backend.user.service;

import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Instant;
import java.util.Map;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class UsernameUpdateConcurrencyIntegrationTest extends AbstractPostgresIntegrationTest {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PlatformTransactionManager transactionManager;

    @Test
    @DisplayName("two independent PostgreSQL transactions racing for one username produce one success and one conflict")
    void updateUsername_concurrentRace_shouldAllowExactlyOneWinner() throws Exception {
        UUID firstUserId = createActiveUser("first");
        UUID secondUserId = createActiveUser("second");
        Map<UUID, UserSnapshot> before = Map.of(
                firstUserId, snapshot(firstUserId),
                secondUserId, snapshot(secondUserId)
        );
        CountDownLatch ready = new CountDownLatch(2);
        CountDownLatch start = new CountDownLatch(1);

        ExecutorService executor = Executors.newFixedThreadPool(2);
        try {
            Future<Outcome> first = executor.submit(updateAfterBarrier(firstUserId, ready, start));
            Future<Outcome> second = executor.submit(updateAfterBarrier(secondUserId, ready, start));
            assertTrue(ready.await(5, TimeUnit.SECONDS));
            start.countDown();

            List<Outcome> outcomes = List.of(first.get(10, TimeUnit.SECONDS), second.get(10, TimeUnit.SECONDS));
            assertEquals(1, outcomes.stream().filter(Outcome::success).count());
            assertEquals(1, outcomes.stream().filter(outcome -> outcome.errorCode == ErrorCode.USERNAME_ALREADY_EXISTS).count());
            assertEquals(1, userRepository.findByUsername("race_name").stream().count());

            Outcome winner = outcomes.stream().filter(Outcome::success).findFirst().orElseThrow();
            Outcome loser = outcomes.stream().filter(outcome -> !outcome.success()).findFirst().orElseThrow();
            assertEquals("race_name", userRepository.findById(winner.userId).orElseThrow().getUsername());
            UserEntity losingUser = userRepository.findById(loser.userId).orElseThrow();
            UserSnapshot losingBefore = before.get(loser.userId);
            assertEquals(losingBefore.username, losingUser.getUsername());
            assertEquals(losingBefore.updatedAt, losingUser.getUpdatedAt());
        } finally {
            executor.shutdownNow();
        }
    }

    private Callable<Outcome> updateAfterBarrier(UUID userId, CountDownLatch ready, CountDownLatch start) {
        return () -> {
            try {
                new TransactionTemplate(transactionManager).executeWithoutResult(status -> {
                    UserEntity user = userRepository.findById(userId).orElseThrow();
                    assertTrue(!userRepository.existsByUsername("race_name"));
                    ready.countDown();
                    try {
                        if (!start.await(5, TimeUnit.SECONDS)) {
                            throw new IllegalStateException("Concurrent username update did not start");
                        }
                    } catch (InterruptedException exception) {
                        Thread.currentThread().interrupt();
                        throw new IllegalStateException("Concurrent username update was interrupted", exception);
                    }
                    user.setUsername("race_name");
                    user.setUpdatedAt(Instant.now());
                    userRepository.flush();
                });
                return new Outcome(userId, true, null);
            } catch (DataIntegrityViolationException exception) {
                if (UsernameUniqueViolationDetector.isUsernameUniqueViolation(exception)) {
                    return new Outcome(userId, false, ErrorCode.USERNAME_ALREADY_EXISTS);
                }
                throw exception;
            }
        };
    }

    private UUID createActiveUser(String prefix) {
        UUID id = UUID.randomUUID();
        userRepository.saveAndFlush(new UserEntity(
                id,
                prefix + "." + id + "@example.com",
                prefix + "_" + id.toString().substring(0, 8),
                prefix,
                UserStatus.ACTIVE,
                Instant.now(),
                Instant.now()
        ));
        return id;
    }

    private UserSnapshot snapshot(UUID userId) {
        UserEntity user = userRepository.findById(userId).orElseThrow();
        return new UserSnapshot(user.getUsername(), user.getUpdatedAt());
    }

    private record Outcome(UUID userId, boolean success, ErrorCode errorCode) {
    }

    private record UserSnapshot(String username, Instant updatedAt) {
    }
}
