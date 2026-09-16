package com.wedo.backend.activity.service;

import com.wedo.backend.activity.dto.ChangeRsvpRequest;
import com.wedo.backend.activity.entity.ActivityEntity;
import com.wedo.backend.activity.entity.ActivityLocation;
import com.wedo.backend.activity.entity.ActivityParticipantEntity;
import com.wedo.backend.activity.entity.ActivityRsvpStatus;
import com.wedo.backend.activity.entity.ActivityStatus;
import com.wedo.backend.activity.repository.ActivityParticipantRepository;
import com.wedo.backend.activity.repository.ActivityRepository;
import com.wedo.backend.activity.repository.ActivityRsvpHistoryRepository;
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
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import static org.junit.jupiter.api.Assertions.*;

class ActivityRsvpConcurrencyIntegrationTest extends AbstractPostgresIntegrationTest {
    private static final Instant NOW = Instant.parse("2026-09-15T12:00:00Z");
    @Autowired private ActivityRsvpService rsvp;
    @Autowired private ActivityRepository activities;
    @Autowired private ActivityParticipantRepository participants;
    @Autowired private ActivityRsvpHistoryRepository histories;
    @Autowired private GroupRepository groups;
    @Autowired private GroupMembershipRepository memberships;
    @Autowired private UserRepository users;

    @Test
    void finalSlot_twoIndependentTransactions_leaveOneGoingAndOneWaitlisted() throws Exception {
        Fixture fixture = fixture(1, 2);
        List<Throwable> outcomes = concurrentlyGoing(fixture.activityId(), fixture.memberIds());

        assertTrue(outcomes.stream().allMatch(value -> value == null), outcomes::toString);
        List<ActivityParticipantEntity> state = participants.findProjectionByActivityId(fixture.activityId());
        assertEquals(1, state.stream().filter(p -> p.getRsvpStatus() == ActivityRsvpStatus.GOING).count());
        assertEquals(1, state.stream().filter(p -> p.getRsvpStatus() == ActivityRsvpStatus.WAITLIST).count());
        assertEquals(1, state.stream().filter(p -> p.getRsvpStatus() == ActivityRsvpStatus.WAITLIST && p.getWaitlistSequence() != null).count());
        assertEquals(1, state.stream().filter(p -> p.getRsvpStatus() == ActivityRsvpStatus.GOING && p.getWaitlistSequence() == null).count());
        assertEquals(2, historyCount(fixture.activityId()));
    }

    @Test
    void fullActivity_concurrentWaitlistAllocationAndPromotion_areUniqueAndFifo() throws Exception {
        Fixture fixture = fixture(1, 4);
        UUID initialGoing = fixture.memberIds().getFirst();
        rsvp.changeRsvp(fixture.activityId(), initialGoing, new ChangeRsvpRequest(ActivityRsvpStatus.GOING));
        List<UUID> waiters = fixture.memberIds().subList(1, fixture.memberIds().size());
        assertTrue(concurrentlyGoing(fixture.activityId(), waiters).stream().allMatch(value -> value == null));

        List<ActivityParticipantEntity> beforeRelease = participants.findProjectionByActivityId(fixture.activityId());
        List<Long> sequences = beforeRelease.stream().filter(p -> p.getRsvpStatus() == ActivityRsvpStatus.WAITLIST)
                .map(ActivityParticipantEntity::getWaitlistSequence).sorted().toList();
        assertEquals(List.of(1L, 2L, 3L), sequences);

        rsvp.changeRsvp(fixture.activityId(), initialGoing, new ChangeRsvpRequest(ActivityRsvpStatus.MAYBE));
        List<ActivityParticipantEntity> afterRelease = participants.findProjectionByActivityId(fixture.activityId());
        assertEquals(1, afterRelease.stream().filter(p -> p.getRsvpStatus() == ActivityRsvpStatus.GOING).count());
        ActivityParticipantEntity promoted = afterRelease.stream().filter(p -> p.getRsvpStatus() == ActivityRsvpStatus.GOING).findFirst().orElseThrow();
        UUID firstQueuedUser = beforeRelease.stream().filter(p -> Long.valueOf(1L).equals(p.getWaitlistSequence()))
                .findFirst().orElseThrow().getUserId();
        assertEquals(firstQueuedUser, promoted.getUserId());
        assertNull(promoted.getWaitlistSequence());
        assertEquals(List.of(2L, 3L), afterRelease.stream().filter(p -> p.getRsvpStatus() == ActivityRsvpStatus.WAITLIST)
                .map(ActivityParticipantEntity::getWaitlistSequence).sorted().toList());
        assertEquals(6, historyCount(fixture.activityId()), "initial GOING, three waitlist changes, MAYBE, and exactly one promotion");
    }

    private List<Throwable> concurrentlyGoing(UUID activityId, List<UUID> users) throws Exception {
        ExecutorService pool = Executors.newFixedThreadPool(users.size());
        CountDownLatch ready = new CountDownLatch(users.size());
        CountDownLatch start = new CountDownLatch(1);
        try {
            List<Future<Throwable>> futures = new ArrayList<>();
            for (UUID userId : users) futures.add(pool.submit(() -> {
                ready.countDown(); start.await();
                try { rsvp.changeRsvp(activityId, userId, new ChangeRsvpRequest(ActivityRsvpStatus.GOING)); return null; }
                catch (Throwable throwable) { return throwable; }
            }));
            assertTrue(ready.await(10, TimeUnit.SECONDS)); start.countDown();
            List<Throwable> result = new ArrayList<>();
            for (Future<Throwable> future : futures) result.add(future.get(30, TimeUnit.SECONDS));
            return result;
        } finally { pool.shutdownNow(); assertTrue(pool.awaitTermination(10, TimeUnit.SECONDS)); }
    }

    private Fixture fixture(int capacity, int members) {
        UUID ownerId = user(); UUID groupId = UUID.randomUUID();
        groups.save(new GroupEntity(groupId, "Activity group", null, null, GroupStatus.ACTIVE, ownerId, NOW, NOW));
        memberships.save(new GroupMembershipEntity(UUID.randomUUID(), groupId, ownerId, GroupRole.OWNER, GroupMembershipStatus.ACTIVE, NOW, null));
        List<UUID> memberIds = new ArrayList<>();
        for (int i = 0; i < members; i++) { UUID member = user(); memberIds.add(member); memberships.save(new GroupMembershipEntity(UUID.randomUUID(), groupId, member, GroupRole.MEMBER, GroupMembershipStatus.ACTIVE, NOW, null)); }
        UUID activityId = UUID.randomUUID();
        activities.save(new ActivityEntity(activityId, groupId, ownerId, "Activity", null, ActivityStatus.CONFIRMED, NOW.plusSeconds(3600), null, "UTC", new ActivityLocation("PHYSICAL", "Venue", null, null, null), capacity, NOW, NOW));
        return new Fixture(activityId, memberIds);
    }

    private UUID user() { UUID id = UUID.randomUUID(); users.save(new UserEntity(id, "activity_" + id + "@test.local", "a_" + id.toString().substring(0, 8), "Activity", UserStatus.ACTIVE, NOW, NOW)); return id; }
    private long historyCount(UUID activityId) { return histories.findAll().stream().filter(history -> history.getActivityId().equals(activityId)).count(); }
    private record Fixture(UUID activityId, List<UUID> memberIds) { }
}
