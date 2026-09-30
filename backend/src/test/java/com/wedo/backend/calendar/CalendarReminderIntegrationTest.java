package com.wedo.backend.calendar;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.wedo.backend.activity.dto.UpdateActivityRequest;
import com.wedo.backend.activity.entity.ActivityEntity;
import com.wedo.backend.activity.entity.ActivityParticipantEntity;
import com.wedo.backend.activity.entity.ActivityRsvpStatus;
import com.wedo.backend.activity.entity.ActivityStatus;
import com.wedo.backend.activity.reminder.ActivityReminderDtos.Request;
import com.wedo.backend.activity.reminder.ActivityReminderEntity;
import com.wedo.backend.activity.reminder.ActivityReminderRepository;
import com.wedo.backend.activity.reminder.ActivityReminderService;
import com.wedo.backend.activity.repository.ActivityParticipantRepository;
import com.wedo.backend.activity.repository.ActivityRepository;
import com.wedo.backend.activity.service.ActivityLifecycleService;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
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
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import java.sql.Timestamp;

class CalendarReminderIntegrationTest extends AbstractPostgresIntegrationTest {
    @Autowired CalendarService calendar;
    @Autowired ActivityReminderService reminderService;
    @Autowired ActivityLifecycleService lifecycle;
    @Autowired UserRepository users;
    @Autowired GroupRepository groups;
    @Autowired GroupMembershipRepository memberships;
    @Autowired ActivityRepository activities;
    @Autowired ActivityParticipantRepository participants;
    @Autowired ActivityReminderRepository reminders;
    @Autowired JdbcTemplate jdbc;

    @Test
    void calendarAggregatesJoinedGroupsAndAppliesInclusiveOverlapAndFilters() {
        Fixture fixture = fixture();
        UUID secondGroup = group(fixture.viewer, "second", GroupStatus.ACTIVE);
        UUID outsideGroup = group(fixture.outsider, "outside", GroupStatus.ACTIVE);
        membership(secondGroup, fixture.viewer, GroupRole.MEMBER);

        Instant from = Instant.parse("2026-10-02T00:00:00Z");
        Instant to = Instant.parse("2026-10-02T03:00:00Z");
        ActivityEntity spanning = activity(fixture.group, fixture.viewer, "spanning", ActivityStatus.CONFIRMED,
                from.minusSeconds(1800), to.minusSeconds(1800), "Asia/Bangkok");
        ActivityEntity boundary = activity(secondGroup, fixture.viewer, "boundary", ActivityStatus.PLANNING,
                to, null, "UTC");
        activity(fixture.group, fixture.viewer, "before", ActivityStatus.CONFIRMED,
                from.minusSeconds(7200), from.minusSeconds(1801), "UTC");
        activity(outsideGroup, fixture.viewer, "outsider group", ActivityStatus.CONFIRMED,
                from, null, "UTC");
        ActivityEntity cancelled = activity(fixture.group, fixture.viewer, "cancelled", ActivityStatus.CANCELLED,
                from.plusSeconds(60), null, "UTC");
        participants.save(new ActivityParticipantEntity(UUID.randomUUID(), spanning.getId(), fixture.viewer,
                ActivityRsvpStatus.GOING, null, from, from, from));
        participants.save(new ActivityParticipantEntity(UUID.randomUUID(), boundary.getId(), fixture.viewer,
                ActivityRsvpStatus.MAYBE, null, from, from, from));
        participants.save(new ActivityParticipantEntity(UUID.randomUUID(), spanning.getId(), fixture.other,
                ActivityRsvpStatus.GOING, null, from, from, from));

        List<CalendarActivityResponse> all = calendar.activities(
                OffsetDateTime.ofInstant(from, ZoneOffset.UTC), OffsetDateTime.ofInstant(to, ZoneOffset.UTC),
                null, null, null, fixture.viewer);

        assertThat(all).extracting(CalendarActivityResponse::id)
                .containsExactly(spanning.getId(), cancelled.getId(), boundary.getId());
        assertThat(all.getFirst().goingCount()).isEqualTo(2);
        assertThat(all.getFirst().callerRsvpStatus()).isEqualTo(ActivityRsvpStatus.GOING);

        List<CalendarActivityResponse> filtered = calendar.activities(
                OffsetDateTime.ofInstant(from, ZoneOffset.UTC), OffsetDateTime.ofInstant(to, ZoneOffset.UTC),
                ActivityRsvpStatus.MAYBE, secondGroup, ActivityStatus.PLANNING, fixture.viewer);
        assertThat(filtered).extracting(CalendarActivityResponse::id).containsExactly(boundary.getId());

        List<CalendarActivityResponse> cancelledOnly = calendar.activities(null, null, null,
                fixture.group, ActivityStatus.CANCELLED, fixture.viewer);
        assertThat(cancelledOnly).extracting(CalendarActivityResponse::id).containsExactly(cancelled.getId());
    }

    @Test
    void calendarRejectsReversedOffsetAwareRange() {
        Fixture fixture = fixture();
        assertThatThrownBy(() -> calendar.activities(
                OffsetDateTime.parse("2026-10-02T10:00:00+07:00"),
                OffsetDateTime.parse("2026-10-02T02:00:00Z"), null, null, null, fixture.viewer))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode").isEqualTo(ErrorCode.VALIDATION_FAILED);
    }

    @Test
    void reminderGetIsUnconfiguredWithoutLazyInsertAndPutIsIdempotentPerUser() {
        Fixture fixture = fixture();
        ActivityEntity activity = activity(fixture.group, fixture.viewer, "reminder", ActivityStatus.CONFIRMED,
                Instant.now().plusSeconds(86400), null, "Asia/Bangkok");

        var empty = reminderService.get(activity.getId(), fixture.viewer);
        assertThat(empty.configured()).isFalse();
        assertThat(empty.enabled()).isFalse();
        assertThat(empty.offsetMinutes()).isNull();
        assertThat(reminders.findByActivityIdAndUserId(activity.getId(), fixture.viewer)).isEmpty();

        var saved = reminderService.put(activity.getId(), fixture.viewer, new Request(true, 60));
        UUID rowId = reminders.findByActivityIdAndUserId(activity.getId(), fixture.viewer).orElseThrow().getId();
        var repeated = reminderService.put(activity.getId(), fixture.viewer, new Request(true, 60));
        assertThat(saved.configured()).isTrue();
        assertThat(saved.remindAt()).isEqualTo(postgresInstant(activity.getStartAt()).minusSeconds(3600));
        assertThat(reminders.findByActivityIdAndUserId(activity.getId(), fixture.viewer).orElseThrow().getId())
                .isEqualTo(rowId);
        assertThat(repeated.remindAt()).isEqualTo(saved.remindAt());

        var disabled = reminderService.put(activity.getId(), fixture.viewer, new Request(false, null));
        assertThat(disabled.enabled()).isFalse();
        var reenabled = reminderService.put(activity.getId(), fixture.viewer, new Request(true, 60));
        assertThat(reenabled.enabled()).isTrue();
        assertThat(reminders.findAll()).filteredOn(r -> r.getActivityId().equals(activity.getId())).hasSize(1);
    }

    @Test
    void remindersAreUserScopedValidateOffsetsAndHideOutsiderActivities() {
        Fixture fixture = fixture();
        ActivityEntity activity = activity(fixture.group, fixture.viewer, "private", ActivityStatus.PLANNING,
                Instant.now().plusSeconds(7200), null, "UTC");
        assertThatThrownBy(() -> reminderService.get(activity.getId(), fixture.outsider))
                .isInstanceOf(BusinessException.class);
        assertThatThrownBy(() -> reminderService.put(activity.getId(), fixture.viewer, new Request(true, 0)))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode").isEqualTo(ErrorCode.ACTIVITY_REMINDER_OFFSET_INVALID);

        reminderService.put(activity.getId(), fixture.viewer, new Request(true, 30));
        reminderService.put(activity.getId(), fixture.other, new Request(true, 90));
        assertThat(reminders.findAll()).filteredOn(r -> r.getActivityId().equals(activity.getId())).hasSize(2);

        activity.transitionTo(ActivityStatus.CANCELLED, Instant.now());
        activities.saveAndFlush(activity);
        assertThat(reminderService.get(activity.getId(), fixture.viewer).canConfigure()).isFalse();
        assertThatThrownBy(() -> reminderService.put(activity.getId(), fixture.viewer, new Request(true, 15)))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode").isEqualTo(ErrorCode.ACTIVITY_REMINDER_NOT_ALLOWED);
    }

    @Test
    void archivedGroupReminderIsReadableButCannotBeEnabled() {
        Fixture fixture = fixture();
        UUID archivedGroup = group(fixture.viewer, "archived", GroupStatus.ARCHIVED);
        membership(archivedGroup, fixture.viewer, GroupRole.OWNER);
        ActivityEntity activity = activity(archivedGroup, fixture.viewer, "archived event",
                ActivityStatus.CONFIRMED, Instant.now().plusSeconds(3600), null, "UTC");

        var reminder = reminderService.get(activity.getId(), fixture.viewer);

        assertThat(reminder.configured()).isFalse();
        assertThat(reminder.canConfigure()).isFalse();
        assertThat(reminder.unavailableReason()).isEqualTo("GROUP_ARCHIVED");
        assertThatThrownBy(() -> reminderService.put(activity.getId(), fixture.viewer, new Request(true, 15)))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode").isEqualTo(ErrorCode.GROUP_ARCHIVED);
    }

    @Test
    void activityTimeChangeReschedulesOnlyEnabledUnsentReminderInSameTransaction() {
        Fixture fixture = fixture();
        Instant oldStart = Instant.now().plusSeconds(172800);
        Instant newStart = oldStart.plusSeconds(7200);
        ActivityEntity activity = activity(fixture.group, fixture.viewer, "edit", ActivityStatus.CONFIRMED,
                oldStart, null, "UTC");
        var enabled = reminders.save(new ActivityReminderEntity(UUID.randomUUID(), activity.getId(), fixture.viewer,
                true, 60, oldStart.minusSeconds(3600), Instant.now()));
        var disabled = reminders.save(new ActivityReminderEntity(UUID.randomUUID(), activity.getId(), fixture.other,
                false, 30, oldStart.minusSeconds(1800), Instant.now()));
        var sent = reminders.save(new ActivityReminderEntity(UUID.randomUUID(), activity.getId(), fixture.outsider,
                true, 15, oldStart.minusSeconds(900), Instant.now()));
        jdbc.update("UPDATE user_activity_reminders SET sent_at = ? WHERE id = ?", Timestamp.from(Instant.now()), sent.getId());

        lifecycle.update(activity.getId(), fixture.viewer, new UpdateActivityRequest(
                null, null, newStart, null, null, null, null));

        assertThat(reminders.findById(enabled.getId()).orElseThrow().getRemindAt())
                .isEqualTo(postgresInstant(newStart).minusSeconds(3600));
        assertThat(reminders.findById(disabled.getId()).orElseThrow().getRemindAt())
                .isEqualTo(postgresInstant(oldStart).minusSeconds(1800));
        assertThat(reminders.findById(sent.getId()).orElseThrow().getRemindAt())
                .isEqualTo(postgresInstant(oldStart).minusSeconds(900));
    }

    private Fixture fixture() {
        Instant now = Instant.now();
        UUID viewer = user("viewer");
        UUID other = user("other");
        UUID outsider = user("outsider");
        UUID group = group(viewer, "primary", GroupStatus.ACTIVE);
        membership(group, viewer, GroupRole.OWNER);
        membership(group, other, GroupRole.MEMBER);
        return new Fixture(viewer, other, outsider, group);
    }

    private UUID user(String label) {
        UUID id = UUID.randomUUID();
        Instant now = Instant.now();
        users.save(new UserEntity(id, id + "+" + label + "@m15.test", "m15_" + label + "_" + id,
                label, UserStatus.ACTIVE, now, now));
        return id;
    }

    private UUID group(UUID owner, String label, GroupStatus status) {
        UUID id = UUID.randomUUID();
        Instant now = Instant.now();
        groups.save(new GroupEntity(id, "M15 " + label + " " + id, null, null, status, owner, now, now));
        return id;
    }

    private void membership(UUID groupId, UUID userId, GroupRole role) {
        memberships.save(new GroupMembershipEntity(UUID.randomUUID(), groupId, userId, role,
                GroupMembershipStatus.ACTIVE, Instant.now(), null));
    }

    private ActivityEntity activity(UUID group, UUID creator, String title, ActivityStatus status,
                                    Instant start, Instant end, String timezone) {
        Instant now = Instant.now();
        return activities.saveAndFlush(new ActivityEntity(UUID.randomUUID(), group, creator, title, null,
                status, start, end, timezone, null, null, now, now));
    }

    private Instant postgresInstant(Instant value) {
        return value.plusNanos(500).truncatedTo(ChronoUnit.MICROS);
    }

    private record Fixture(UUID viewer, UUID other, UUID outsider, UUID group) { }
}
