package com.wedo.backend.activity.service;

import static org.junit.jupiter.api.Assertions.*;

import com.wedo.backend.activity.dto.ActivityDetailResponse;
import com.wedo.backend.activity.dto.ActivityRsvpResponse;
import com.wedo.backend.activity.dto.ChangeRsvpRequest;
import com.wedo.backend.activity.entity.*;
import com.wedo.backend.activity.repository.ActivityParticipantRepository;
import com.wedo.backend.activity.repository.ActivityRepository;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.group.entity.*;
import com.wedo.backend.group.repository.GroupMembershipRepository;
import com.wedo.backend.group.repository.GroupRepository;
import com.wedo.backend.group.service.GroupPermissionService;
import com.wedo.backend.group.service.ReadableGroupAccess;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserRepository;
import java.time.Duration;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

class ActivityRsvpLifecycleIntegrationTest extends AbstractPostgresIntegrationTest {

    @Autowired private ActivityRepository activities;
    @Autowired private ActivityParticipantRepository participants;
    @Autowired private GroupRepository groups;
    @Autowired private GroupMembershipRepository memberships;
    @Autowired private UserRepository users;
    @Autowired private ActivityRsvpService rsvpService;
    @Autowired private ActivityResponseFactory responseFactory;
    @Autowired private GroupPermissionService permissionService;

    private UUID ownerId;
    private UUID memberId;
    private UUID groupId;
    private Instant now;

    @BeforeEach
    void setUp() {
        now = Instant.now();
        ownerId = createUser("owner_" + UUID.randomUUID().toString().substring(0, 8));
        memberId = createUser("member_" + UUID.randomUUID().toString().substring(0, 8));
        groupId = UUID.randomUUID();

        groups.save(new GroupEntity(groupId, "Test Group", null, null, GroupStatus.ACTIVE, ownerId, now, now));
        memberships.save(new GroupMembershipEntity(UUID.randomUUID(), groupId, ownerId, GroupRole.OWNER, GroupMembershipStatus.ACTIVE, now, null));
        memberships.save(new GroupMembershipEntity(UUID.randomUUID(), groupId, memberId, GroupRole.MEMBER, GroupMembershipStatus.ACTIVE, now, null));
    }

    @Test
    @DisplayName("Case A: Unscheduled PLANNING Activity allows RSVP")
    void caseA_unscheduledPlanning_allowsRsvp() {
        ActivityEntity activity = createActivity("Unscheduled Plan", ActivityStatus.PLANNING, null, null);

        ReadableGroupAccess access = permissionService.requireReadableMembership(groupId, memberId);
        ActivityDetailResponse detail = responseFactory.detail(activity, memberId, access);

        assertEquals(ActivityStatus.PLANNING, detail.status());
        assertTrue(detail.permissions().canRsvp(), "Unscheduled PLANNING activity must allow RSVP");

        ActivityRsvpResponse rsvp = rsvpService.changeRsvp(activity.getId(), memberId, new ChangeRsvpRequest(ActivityRsvpStatus.GOING));
        assertEquals(ActivityRsvpStatus.GOING, rsvp.status());
    }

    @Test
    @DisplayName("Case B: Scheduled future PLANNING Activity allows RSVP")
    void caseB_scheduledFuturePlanning_allowsRsvp() {
        Instant start = now.plus(Duration.ofDays(2));
        Instant end = now.plus(Duration.ofDays(3));
        ActivityEntity activity = createActivity("Future Plan", ActivityStatus.PLANNING, start, end);

        ReadableGroupAccess access = permissionService.requireReadableMembership(groupId, memberId);
        ActivityDetailResponse detail = responseFactory.detail(activity, memberId, access);

        assertEquals(ActivityStatus.PLANNING, detail.status());
        assertTrue(detail.permissions().canRsvp(), "Future PLANNING activity must allow RSVP");

        ActivityRsvpResponse rsvp = rsvpService.changeRsvp(activity.getId(), memberId, new ChangeRsvpRequest(ActivityRsvpStatus.GOING));
        assertEquals(ActivityRsvpStatus.GOING, rsvp.status());
    }

    @Test
    @DisplayName("Case C: Future CONFIRMED Activity allows RSVP")
    void caseC_futureConfirmed_allowsRsvp() {
        Instant start = now.plus(Duration.ofDays(2));
        Instant end = now.plus(Duration.ofDays(3));
        ActivityEntity activity = createActivity("Future Confirmed", ActivityStatus.CONFIRMED, start, end);

        ReadableGroupAccess access = permissionService.requireReadableMembership(groupId, memberId);
        ActivityDetailResponse detail = responseFactory.detail(activity, memberId, access);

        assertEquals(ActivityStatus.CONFIRMED, detail.status());
        assertTrue(detail.permissions().canRsvp(), "Future CONFIRMED activity must allow RSVP");

        ActivityRsvpResponse rsvp = rsvpService.changeRsvp(activity.getId(), memberId, new ChangeRsvpRequest(ActivityRsvpStatus.GOING));
        assertEquals(ActivityRsvpStatus.GOING, rsvp.status());
    }

    @Test
    @DisplayName("Case D: Current IN_PROGRESS Activity allows RSVP")
    void caseD_currentInProgress_allowsRsvp() {
        Instant start = now.minus(Duration.ofHours(1));
        Instant end = now.plus(Duration.ofHours(2));
        ActivityEntity activity = createActivity("Current In Progress", ActivityStatus.CONFIRMED, start, end);

        ReadableGroupAccess access = permissionService.requireReadableMembership(groupId, memberId);
        ActivityDetailResponse detail = responseFactory.detail(activity, memberId, access);

        assertEquals(ActivityStatus.IN_PROGRESS, detail.status(), "Effective status during active interval must be IN_PROGRESS");
        assertTrue(detail.permissions().canRsvp(), "IN_PROGRESS activity must allow RSVP per product rule");

        ActivityRsvpResponse rsvp = rsvpService.changeRsvp(activity.getId(), memberId, new ChangeRsvpRequest(ActivityRsvpStatus.GOING));
        assertEquals(ActivityRsvpStatus.GOING, rsvp.status());
    }

    @Test
    @DisplayName("Case E: COMPLETED Activity locks RSVP")
    void caseE_completed_locksRsvp() {
        // Test explicit COMPLETED status
        ActivityEntity activity = createActivity("Completed Activity", ActivityStatus.COMPLETED, null, null);

        ReadableGroupAccess access = permissionService.requireReadableMembership(groupId, memberId);
        ActivityDetailResponse detail = responseFactory.detail(activity, memberId, access);

        assertEquals(ActivityStatus.COMPLETED, detail.status());
        assertFalse(detail.permissions().canRsvp(), "COMPLETED activity must NOT allow RSVP");

        BusinessException ex = assertThrows(BusinessException.class, () ->
                rsvpService.changeRsvp(activity.getId(), memberId, new ChangeRsvpRequest(ActivityRsvpStatus.GOING)));
        assertEquals(ErrorCode.RSVP_LOCKED, ex.errorCode());

        // Test time-based completed: endAt in the past
        Instant pastStart = now.minus(Duration.ofHours(3));
        Instant pastEnd = now.minus(Duration.ofHours(1));
        ActivityEntity pastActivity = createActivity("Past Activity", ActivityStatus.CONFIRMED, pastStart, pastEnd);
        ActivityDetailResponse pastDetail = responseFactory.detail(pastActivity, memberId, access);

        assertEquals(ActivityStatus.COMPLETED, pastDetail.status(), "Activity with past endAt must effectively be COMPLETED");
        assertFalse(pastDetail.permissions().canRsvp(), "Past activity must lock RSVP");

        BusinessException pastEx = assertThrows(BusinessException.class, () ->
                rsvpService.changeRsvp(pastActivity.getId(), memberId, new ChangeRsvpRequest(ActivityRsvpStatus.GOING)));
        assertEquals(ErrorCode.RSVP_LOCKED, pastEx.errorCode());
    }

    @Test
    @DisplayName("Case F: CANCELLED Activity locks RSVP")
    void caseF_cancelled_locksRsvp() {
        ActivityEntity activity = createActivity("Cancelled Match", ActivityStatus.CANCELLED, null, null);

        ReadableGroupAccess access = permissionService.requireReadableMembership(groupId, memberId);
        ActivityDetailResponse detail = responseFactory.detail(activity, memberId, access);

        assertEquals(ActivityStatus.CANCELLED, detail.status());
        assertFalse(detail.permissions().canRsvp(), "CANCELLED activity must NOT allow RSVP");

        BusinessException ex = assertThrows(BusinessException.class, () ->
                rsvpService.changeRsvp(activity.getId(), memberId, new ChangeRsvpRequest(ActivityRsvpStatus.GOING)));
        assertEquals(ErrorCode.RSVP_LOCKED, ex.errorCode());
    }

    private ActivityEntity createActivity(String title, ActivityStatus status, Instant startAt, Instant endAt) {
        return activities.save(new ActivityEntity(
                UUID.randomUUID(),
                groupId,
                ownerId,
                title,
                "Description for " + title,
                status,
                startAt,
                endAt,
                startAt == null ? null : "Asia/Ho_Chi_Minh",
                null,
                null,
                now,
                now
        ));
    }

    private UUID createUser(String username) {
        UUID id = UUID.randomUUID();
        users.save(new UserEntity(
                id,
                username + "@wedo.test",
                username,
                "User " + username,
                UserStatus.ACTIVE,
                now,
                now
        ));
        return id;
    }
}
