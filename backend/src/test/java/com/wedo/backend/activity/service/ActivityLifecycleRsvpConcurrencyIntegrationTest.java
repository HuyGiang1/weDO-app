package com.wedo.backend.activity.service;

import com.wedo.backend.activity.dto.ChangeRsvpRequest;
import com.wedo.backend.activity.dto.UpdateActivityRequest;
import com.wedo.backend.activity.entity.*;
import com.wedo.backend.activity.repository.ActivityParticipantRepository;
import com.wedo.backend.activity.repository.ActivityRepository;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.group.entity.GroupEntity;
import com.wedo.backend.group.entity.GroupMembershipEntity;
import com.wedo.backend.group.entity.GroupMembershipStatus;
import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.group.repository.GroupMembershipRepository;
import com.wedo.backend.group.repository.GroupRepository;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserRepository;
import java.time.Duration;
import java.time.Instant;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.RepeatedTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Concurrency test verifying that ActivityLifecycleService and ActivityRsvpService
 * do NOT deadlock when executed simultaneously on the same activity and group.
 */
class ActivityLifecycleRsvpConcurrencyIntegrationTest extends AbstractPostgresIntegrationTest {

    @Autowired private ActivityLifecycleService lifecycle;
    @Autowired private ActivityRsvpService rsvp;
    @Autowired private ActivityRepository activities;
    @Autowired private ActivityParticipantRepository participants;
    @Autowired private GroupRepository groups;
    @Autowired private GroupMembershipRepository memberships;
    @Autowired private UserRepository users;

    @RepeatedTest(3)
    void raceUpdateAndRsvp_doesNotDeadlockAndPreservesConsistency() throws Exception {
        Instant now = Instant.now();
        Instant futureStart = now.plus(Duration.ofDays(10));
        Instant futureEnd = now.plus(Duration.ofDays(11));

        UUID ownerId = user(now);
        UUID memberId = user(now);
        UUID groupId = UUID.randomUUID();

        groups.save(new GroupEntity(groupId, "Test Group", null, null, GroupStatus.ACTIVE, ownerId, now, now));
        memberships.save(new GroupMembershipEntity(UUID.randomUUID(), groupId, ownerId, GroupRole.OWNER, GroupMembershipStatus.ACTIVE, now, null));
        memberships.save(new GroupMembershipEntity(UUID.randomUUID(), groupId, memberId, GroupRole.MEMBER, GroupMembershipStatus.ACTIVE, now, null));

        UUID activityId = UUID.randomUUID();
        activities.save(new ActivityEntity(
                activityId, groupId, ownerId, "Original Title", "Desc",
                ActivityStatus.CONFIRMED, futureStart, futureEnd,
                "UTC", new ActivityLocation("PHYSICAL", "Original Park", null, null, null),
                10, now, now
        ));

        ExecutorService pool = Executors.newFixedThreadPool(2);
        CountDownLatch ready = new CountDownLatch(2);
        CountDownLatch start = new CountDownLatch(1);

        try {
            Future<Throwable> updateFuture = pool.submit(() -> {
                ready.countDown();
                start.await();
                try {
                    lifecycle.update(activityId, ownerId, new UpdateActivityRequest(
                            "Updated Title", null, null, null, null, null, 15
                    ));
                    return null;
                } catch (Throwable t) {
                    return t;
                }
            });

            Future<Throwable> rsvpFuture = pool.submit(() -> {
                ready.countDown();
                start.await();
                try {
                    rsvp.changeRsvp(activityId, memberId, new ChangeRsvpRequest(ActivityRsvpStatus.GOING));
                    return null;
                } catch (Throwable t) {
                    return t;
                }
            });

            assertTrue(ready.await(5, TimeUnit.SECONDS), "Threads must be ready");
            start.countDown();

            Throwable updateError = updateFuture.get(10, TimeUnit.SECONDS);
            Throwable rsvpError = rsvpFuture.get(10, TimeUnit.SECONDS);

            assertNull(updateError, () -> "Update failed unexpectedly: " + updateError);
            assertNull(rsvpError, () -> "RSVP failed unexpectedly: " + rsvpError);

            ActivityEntity current = activities.findById(activityId).orElseThrow();
            assertEquals("Updated Title", current.getTitle());
            assertEquals(15, current.getCapacity());

            ActivityParticipantEntity participant = participants
                    .findByActivityIdAndUserId(activityId, memberId)
                    .orElseThrow();
            assertEquals(ActivityRsvpStatus.GOING, participant.getRsvpStatus());
        } finally {
            pool.shutdownNow();
            assertTrue(pool.awaitTermination(5, TimeUnit.SECONDS));
        }
    }

    @Test
    void raceCancelAndRsvp_doesNotDeadlockAndFailsCleanlyIfCancelledFirst() throws Exception {
        Instant now = Instant.now();
        Instant futureStart = now.plus(Duration.ofDays(10));
        Instant futureEnd = now.plus(Duration.ofDays(11));

        UUID ownerId = user(now);
        UUID memberId = user(now);
        UUID groupId = UUID.randomUUID();

        groups.save(new GroupEntity(groupId, "Test Group 2", null, null, GroupStatus.ACTIVE, ownerId, now, now));
        memberships.save(new GroupMembershipEntity(UUID.randomUUID(), groupId, ownerId, GroupRole.OWNER, GroupMembershipStatus.ACTIVE, now, null));
        memberships.save(new GroupMembershipEntity(UUID.randomUUID(), groupId, memberId, GroupRole.MEMBER, GroupMembershipStatus.ACTIVE, now, null));

        UUID activityId = UUID.randomUUID();
        activities.save(new ActivityEntity(
                activityId, groupId, ownerId, "Activity to cancel", null,
                ActivityStatus.CONFIRMED, futureStart, futureEnd,
                "UTC", null, 5, now, now
        ));

        ExecutorService pool = Executors.newFixedThreadPool(2);
        CountDownLatch ready = new CountDownLatch(2);
        CountDownLatch start = new CountDownLatch(1);

        try {
            Future<Throwable> cancelFuture = pool.submit(() -> {
                ready.countDown();
                start.await();
                try {
                    lifecycle.cancel(activityId, ownerId, "Concurrently cancelled");
                    return null;
                } catch (Throwable t) {
                    return t;
                }
            });

            Future<Throwable> rsvpFuture = pool.submit(() -> {
                ready.countDown();
                start.await();
                try {
                    rsvp.changeRsvp(activityId, memberId, new ChangeRsvpRequest(ActivityRsvpStatus.GOING));
                    return null;
                } catch (Throwable t) {
                    return t;
                }
            });

            assertTrue(ready.await(5, TimeUnit.SECONDS));
            start.countDown();

            Throwable cancelError = cancelFuture.get(10, TimeUnit.SECONDS);
            Throwable rsvpError = rsvpFuture.get(10, TimeUnit.SECONDS);

            assertNull(cancelError, () -> "Cancel failed: " + cancelError);
            if (rsvpError != null) {
                // If cancel committed first, RSVP throws RSVP_LOCKED (which is expected and clean)
                assertTrue(rsvpError instanceof BusinessException, "Unexpected error: " + rsvpError);
            }

            ActivityEntity current = activities.findById(activityId).orElseThrow();
            assertEquals(ActivityStatus.CANCELLED, current.getStatus());
        } finally {
            pool.shutdownNow();
            assertTrue(pool.awaitTermination(5, TimeUnit.SECONDS));
        }
    }

    private UUID user(Instant now) {
        UUID id = UUID.randomUUID();
        users.save(new UserEntity(
                id, "activity_race_" + id + "@test.local",
                "race_" + id.toString().substring(0, 8),
                "Activity Racer", UserStatus.ACTIVE, now, now
        ));
        return id;
    }
}
