package com.wedo.backend.activity.reminder;

import static org.assertj.core.api.Assertions.assertThat;

import com.wedo.backend.activity.dto.UpdateActivityRequest;
import com.wedo.backend.activity.entity.ActivityEntity;
import com.wedo.backend.activity.entity.ActivityStatus;
import com.wedo.backend.activity.repository.ActivityRepository;
import com.wedo.backend.activity.service.ActivityLifecycleService;
import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.group.entity.GroupEntity;
import com.wedo.backend.group.entity.GroupMembershipEntity;
import com.wedo.backend.group.entity.GroupMembershipStatus;
import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.entity.GroupSettingsEntity;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.group.repository.GroupMembershipRepository;
import com.wedo.backend.group.repository.GroupRepository;
import com.wedo.backend.group.repository.GroupSettingsRepository;
import com.wedo.backend.notification.dto.NotificationDtos.NotificationItemResponse;
import com.wedo.backend.notification.dto.NotificationDtos.RegisterDeviceRequest;
import com.wedo.backend.notification.dto.NotificationDtos.UpdateGroupNotificationSettingsRequest;
import com.wedo.backend.notification.dto.NotificationDtos.UpdateUserNotificationSettingsRequest;
import com.wedo.backend.notification.dto.NotificationDtos.UserDeviceResponse;
import com.wedo.backend.notification.push.PushGateway;
import com.wedo.backend.notification.push.PushGateway.PushDeliveryResult;
import com.wedo.backend.notification.push.PushGateway.PushMessage;
import com.wedo.backend.notification.service.NotificationService;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserRepository;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.CopyOnWriteArrayList;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.TestPropertySource;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

@Import(ActivityReminderDeliveryIntegrationTest.FakePushConfiguration.class)
@TestPropertySource(properties = "wedo.reminders.scheduler.fixed-delay-ms=86400000")
class ActivityReminderDeliveryIntegrationTest extends AbstractPostgresIntegrationTest {
    @Autowired ActivityReminderDeliveryScheduler scheduler;
    @Autowired ActivityReminderRepository reminders;
    @Autowired ActivityRepository activities;
    @Autowired ActivityReminderService reminderService;
    @Autowired ActivityLifecycleService activityLifecycle;
    @Autowired NotificationService notificationService;
    @Autowired FakePushGateway pushGateway;
    @Autowired UserRepository users;
    @Autowired GroupRepository groups;
    @Autowired GroupMembershipRepository memberships;
    @Autowired GroupSettingsRepository groupSettings;
    @Autowired JdbcTemplate jdbc;
    @Autowired PlatformTransactionManager transactionManager;

    @TestConfiguration(proxyBeanMethods = false)
    static class FakePushConfiguration {
        @Bean
        @Primary
        FakePushGateway fakeReminderPushGateway() {
            return new FakePushGateway();
        }
    }

    static final class FakePushGateway implements PushGateway {
        private final List<PushMessage> messages = new CopyOnWriteArrayList<>();
        private final Set<String> invalidTokens = java.util.concurrent.ConcurrentHashMap.newKeySet();
        private final AtomicBoolean failTransiently = new AtomicBoolean();

        @Override
        public PushDeliveryResult sendPush(PushMessage message) {
            messages.add(message);
            if (failTransiently.get()) throw new IllegalStateException("Simulated transient provider failure");
            if (invalidTokens.contains(message.pushToken())) {
                return PushDeliveryResult.invalidToken("UNREGISTERED", "Test token is invalid");
            }
            return PushDeliveryResult.gatewayAccepted("test-provider-accepted");
        }

        void reset() {
            messages.clear();
            invalidTokens.clear();
            failTransiently.set(false);
        }
    }

    @BeforeEach
    void resetGateway() {
        pushGateway.reset();
        jdbc.update("DELETE FROM notifications WHERE user_id IN " + reminderTestUsers());
        jdbc.update("DELETE FROM user_activity_reminders WHERE user_id IN " + reminderTestUsers()
                + " OR activity_id IN (SELECT id FROM activities WHERE created_by IN " + reminderTestUsers() + ")");
        jdbc.update("DELETE FROM activities WHERE created_by IN " + reminderTestUsers());
        jdbc.update("DELETE FROM group_notification_settings WHERE user_id IN " + reminderTestUsers()
                + " OR group_id IN (SELECT id FROM groups WHERE created_by IN " + reminderTestUsers() + ")");
        jdbc.update("DELETE FROM group_memberships WHERE user_id IN " + reminderTestUsers()
                + " OR group_id IN (SELECT id FROM groups WHERE created_by IN " + reminderTestUsers() + ")");
        jdbc.update("DELETE FROM group_settings WHERE group_id IN "
                + "(SELECT id FROM groups WHERE created_by IN " + reminderTestUsers() + ")");
        jdbc.update("DELETE FROM groups WHERE created_by IN " + reminderTestUsers());
        jdbc.update("DELETE FROM users WHERE email LIKE '%@m15-reminder.test'");
    }

    @Test
    void dueReminderPersistsOneInboxAndHandsOffOneActivityDeepLink() {
        Fixture fixture = fixture();
        ActivityEntity activity = dueActivity(fixture);
        ActivityReminderEntity reminder = reminder(fixture, activity, true, 60,
                activity.getStartAt().minusSeconds(3600));
        notificationService.registerDevice(fixture.member(), new RegisterDeviceRequest(
                "m15-reminder-device", "ANDROID", "test-token-" + UUID.randomUUID()));

        assertThat(scheduler.processDueBatch()).isEqualTo(1);

        ActivityReminderEntity delivered = reminders.findById(reminder.getId()).orElseThrow();
        assertThat(delivered.getSentAt()).isNotNull();
        List<NotificationItemResponse> inbox = inbox(fixture.member());
        assertThat(inbox).hasSize(1);
        NotificationItemResponse item = inbox.getFirst();
        assertThat(item.category()).isEqualTo("ACTIVITY");
        assertThat(item.priority()).isEqualTo("NORMAL");
        assertThat(item.critical()).isFalse();
        assertThat(item.target().targetType()).isEqualTo("ACTIVITY");
        assertThat(item.target().targetId()).isEqualTo(activity.getId());
        assertThat(item.target().route()).isEqualTo("/activities/detail");
        assertThat(item.target().params()).doesNotContainKey("eventKey");
        assertThat(pushGateway.messages).hasSize(1);
        assertThat(pushGateway.messages.getFirst().data())
                .containsEntry("targetType", "ACTIVITY")
                .containsEntry("targetId", activity.getId().toString())
                .containsEntry("activityId", activity.getId().toString())
                .doesNotContainKey("eventKey");

        String eventKey = jdbc.queryForObject(
                "SELECT data->>'eventKey' FROM notifications WHERE id = ?", String.class, item.id());
        assertThat(eventKey).startsWith("activity-reminder:" + fixture.member() + ":" + activity.getId() + ":");
        assertThat(scheduler.processDueBatch()).isZero();
        assertThat(inbox(fixture.member())).hasSize(1);
        assertThat(pushGateway.messages).hasSize(1);
    }

    @Test
    void futureDisabledSentStartedAndTerminalRemindersAreNotCandidates() {
        Fixture fixture = fixture();
        ActivityEntity future = activity(fixture, "future", ActivityStatus.CONFIRMED,
                Instant.now().plus(61, ChronoUnit.MINUTES));
        reminder(fixture, future, true, 60, future.getStartAt().minusSeconds(3600));

        ActivityEntity disabled = dueActivity(fixture, "disabled", ActivityStatus.CONFIRMED);
        reminder(fixture, disabled, false, 60, disabled.getStartAt().minusSeconds(3600));

        ActivityEntity sent = dueActivity(fixture, "sent", ActivityStatus.CONFIRMED);
        ActivityReminderEntity sentReminder = reminder(fixture, sent, true, 60, sent.getStartAt().minusSeconds(3600));
        jdbc.update("UPDATE user_activity_reminders SET sent_at = ? WHERE id = ?",
                Timestamp.from(Instant.now()), sentReminder.getId());

        ActivityEntity cancelled = dueActivity(fixture, "cancelled", ActivityStatus.CANCELLED);
        reminder(fixture, cancelled, true, 60, cancelled.getStartAt().minusSeconds(3600));

        ActivityEntity completed = dueActivity(fixture, "completed", ActivityStatus.COMPLETED);
        reminder(fixture, completed, true, 60, completed.getStartAt().minusSeconds(3600));

        ActivityEntity started = activity(fixture, "started", ActivityStatus.IN_PROGRESS,
                Instant.now().plus(59, ChronoUnit.MINUTES));
        reminder(fixture, started, true, 60, started.getStartAt().minusSeconds(3600));

        assertThat(scheduler.processDueBatch()).isZero();
        assertThat(inbox(fixture.member())).isEmpty();
        assertThat(reminders.findById(sentReminder.getId()).orElseThrow().getSentAt()).isNotNull();
        assertThat(pushGateway.messages).isEmpty();
    }

    @Test
    void sentScheduleDoesNotRepeatUntilAChangedOffsetRearmsIt() {
        Fixture fixture = fixture();
        ActivityEntity activity = dueActivity(fixture);
        ActivityReminderEntity reminder = reminder(fixture, activity, true, 60,
                activity.getStartAt().minusSeconds(3600));
        notificationService.registerDevice(fixture.member(), new RegisterDeviceRequest(
                "rearm-device", "ANDROID", "rearm-token-" + UUID.randomUUID()));

        assertThat(scheduler.processDueBatch()).isEqualTo(1);
        Instant firstSentAt = reminders.findById(reminder.getId()).orElseThrow().getSentAt();

        reminderService.put(activity.getId(), fixture.member(), new ActivityReminderDtos.Request(true, 60));
        assertThat(reminders.findById(reminder.getId()).orElseThrow().getSentAt()).isEqualTo(firstSentAt);
        assertThat(scheduler.processDueBatch()).isZero();

        activityLifecycle.update(activity.getId(), fixture.owner(), new UpdateActivityRequest(
                null, null, Instant.now().plusSeconds(120), null, null, null, null));
        assertThat(reminders.findById(reminder.getId()).orElseThrow().getSentAt()).isEqualTo(firstSentAt);
        assertThat(scheduler.processDueBatch()).isZero();

        reminderService.put(activity.getId(), fixture.member(), new ActivityReminderDtos.Request(true, 30));
        assertThat(reminders.findById(reminder.getId()).orElseThrow().getSentAt()).isNull();
        assertThat(scheduler.processDueBatch()).isEqualTo(1);
        assertThat(inbox(fixture.member())).hasSize(2);
        assertThat(pushGateway.messages).hasSize(2);
    }

    @Test
    void reminderInboxPersistsWhenGlobalCategoryOrGroupMuteSuppressesPush() {
        assertSuppressedPush("global");
        assertSuppressedPush("category");
        assertSuppressedPush("mute");
    }

    @Test
    void transientProviderFailureKeepsInboxSentStateAndDeviceActive() {
        Fixture fixture = fixture();
        ActivityEntity activity = dueActivity(fixture);
        ActivityReminderEntity reminder = reminder(fixture, activity, true, 60,
                activity.getStartAt().minusSeconds(3600));
        String token = "transient-token-" + UUID.randomUUID();
        UserDeviceResponse device = notificationService.registerDevice(fixture.member(),
                new RegisterDeviceRequest("transient-device", "ANDROID", token));
        pushGateway.failTransiently.set(true);

        assertThat(scheduler.processDueBatch()).isEqualTo(1);

        assertThat(inbox(fixture.member())).hasSize(1);
        assertThat(reminders.findById(reminder.getId()).orElseThrow().getSentAt()).isNotNull();
        assertThat(jdbc.queryForObject("SELECT active FROM user_devices WHERE id = ?", Boolean.class, device.id()))
                .isTrue();
        assertThat(scheduler.processDueBatch()).isZero();
        assertThat(inbox(fixture.member())).hasSize(1);
    }

    @Test
    void confirmedInvalidTokenIsDeactivatedWithoutAffectingInboxDelivery() {
        Fixture fixture = fixture();
        ActivityEntity activity = dueActivity(fixture);
        ActivityReminderEntity reminder = reminder(fixture, activity, true, 60,
                activity.getStartAt().minusSeconds(3600));
        String token = "invalid-token:" + UUID.randomUUID();
        UserDeviceResponse device = notificationService.registerDevice(fixture.member(),
                new RegisterDeviceRequest("invalid-device", "ANDROID", token));
        pushGateway.invalidTokens.add(token);

        assertThat(scheduler.processDueBatch()).isEqualTo(1);

        assertThat(inbox(fixture.member())).hasSize(1);
        assertThat(reminders.findById(reminder.getId()).orElseThrow().getSentAt()).isNotNull();
        assertThat(jdbc.queryForObject("SELECT active FROM user_devices WHERE id = ?", Boolean.class, device.id()))
                .isFalse();
    }

    @Test
    void twoConcurrentWorkersCreateOneReminderNotificationAndOnePushHandoff() throws Exception {
        Fixture fixture = fixture();
        ActivityEntity activity = dueActivity(fixture);
        ActivityReminderEntity reminder = reminder(fixture, activity, true, 60,
                activity.getStartAt().minusSeconds(3600));
        notificationService.registerDevice(fixture.member(), new RegisterDeviceRequest(
                "concurrent-device", "ANDROID", "concurrent-token-" + UUID.randomUUID()));
        CountDownLatch start = new CountDownLatch(1);
        try (var workers = Executors.newFixedThreadPool(2)) {
            var first = workers.submit(() -> { start.await(); return scheduler.processDueBatch(); });
            var second = workers.submit(() -> { start.await(); return scheduler.processDueBatch(); });
            start.countDown();
            first.get(10, TimeUnit.SECONDS);
            second.get(10, TimeUnit.SECONDS);
        }

        assertThat(reminders.findById(reminder.getId()).orElseThrow().getSentAt()).isNotNull();
        assertThat(inbox(fixture.member())).hasSize(1);
        assertThat(pushGateway.messages).hasSize(1);
    }

    @Test
    void disablingWhileSchedulerCannotLockActivityPreventsDelivery() throws Exception {
        Fixture fixture = fixture();
        ActivityEntity activity = dueActivity(fixture);
        ActivityReminderEntity reminder = reminder(fixture, activity, true, 60,
                activity.getStartAt().minusSeconds(3600));
        CountDownLatch activityLocked = new CountDownLatch(1);
        try (var workers = Executors.newSingleThreadExecutor()) {
            var schedulerResult = workers.submit(() -> {
                assertThat(activityLocked.await(5, TimeUnit.SECONDS)).isTrue();
                return scheduler.processDueBatch();
            });
            new TransactionTemplate(transactionManager).executeWithoutResult(status -> {
                activities.findByIdForUpdate(activity.getId()).orElseThrow();
                activityLocked.countDown();
                try {
                    assertThat(schedulerResult.get(5, TimeUnit.SECONDS)).isZero();
                } catch (Exception exception) {
                    throw new IllegalStateException(exception);
                }
                reminderService.put(activity.getId(), fixture.member(), new ActivityReminderDtos.Request(false, null));
            });
        }

        assertThat(reminders.findById(reminder.getId()).orElseThrow().isEnabled()).isFalse();
        assertThat(reminders.findById(reminder.getId()).orElseThrow().getSentAt()).isNull();
        assertThat(scheduler.processDueBatch()).isZero();
        assertThat(inbox(fixture.member())).isEmpty();
        assertThat(pushGateway.messages).isEmpty();
    }

    @Test
    void activityRescheduleRaceSuppressesOldScheduleAndAllowsOnlyNewScheduleDelivery() throws Exception {
        Fixture fixture = fixture();
        ActivityEntity activity = dueActivity(fixture);
        ActivityReminderEntity reminder = reminder(fixture, activity, true, 60,
                activity.getStartAt().minusSeconds(3600));
        Instant oldSchedule = reminder.getRemindAt();
        CountDownLatch activityLocked = new CountDownLatch(1);
        try (var workers = Executors.newSingleThreadExecutor()) {
            var schedulerResult = workers.submit(() -> {
                assertThat(activityLocked.await(5, TimeUnit.SECONDS)).isTrue();
                return scheduler.processDueBatch();
            });
            new TransactionTemplate(transactionManager).executeWithoutResult(status -> {
                activities.findByIdForUpdate(activity.getId()).orElseThrow();
                activityLocked.countDown();
                try {
                    assertThat(schedulerResult.get(5, TimeUnit.SECONDS)).isZero();
                } catch (Exception exception) {
                    throw new IllegalStateException(exception);
                }
                activityLifecycle.update(activity.getId(), fixture.owner(), new UpdateActivityRequest(
                        null, null, Instant.now().plus(61, ChronoUnit.MINUTES), null, null, null, null));
            });
        }

        ActivityReminderEntity rescheduled = reminders.findById(reminder.getId()).orElseThrow();
        assertThat(rescheduled.getRemindAt()).isAfter(Instant.now());
        assertThat(rescheduled.getRemindAt()).isNotEqualTo(oldSchedule);
        assertThat(scheduler.processDueBatch()).isZero();
        assertThat(inbox(fixture.member())).isEmpty();

        Instant nextStart = Instant.now().plusSeconds(30);
        activityLifecycle.update(activity.getId(), fixture.owner(), new UpdateActivityRequest(
                null, null, nextStart, null, null, null, null));
        Instant newSchedule = reminders.findById(reminder.getId()).orElseThrow().getRemindAt();
        assertThat(newSchedule).isBefore(Instant.now());
        assertThat(scheduler.processDueBatch()).isEqualTo(1);
        assertThat(inbox(fixture.member())).hasSize(1);
        String eventKey = jdbc.queryForObject(
                "SELECT data->>'eventKey' FROM notifications WHERE user_id = ? AND data->>'targetId' = ?",
                String.class, fixture.member(), activity.getId().toString());
        assertThat(eventKey).contains(newSchedule.toString()).doesNotContain(oldSchedule.toString());
    }

    @Test
    void notificationPersistenceFailureLeavesReminderEligibleForRetry() {
        Fixture fixture = fixture();
        ActivityEntity activity = dueActivity(fixture);
        ActivityReminderEntity reminder = reminder(fixture, activity, true, 60,
                activity.getStartAt().minusSeconds(3600));
        jdbc.execute("ALTER TABLE notifications ADD CONSTRAINT chk_test_no_activity_reminder "
                + "CHECK (user_id <> '" + fixture.member() + "'::uuid) NOT VALID");
        try {
            assertThat(scheduler.processDueBatch()).isZero();
        } finally {
            jdbc.execute("ALTER TABLE notifications DROP CONSTRAINT chk_test_no_activity_reminder");
        }

        assertThat(reminders.findById(reminder.getId()).orElseThrow().getSentAt()).isNull();
        assertThat(inbox(fixture.member())).isEmpty();
        assertThat(pushGateway.messages).isEmpty();
    }

    private void assertSuppressedPush(String suppression) {
        Fixture fixture = fixture();
        ActivityEntity activity = dueActivity(fixture);
        ActivityReminderEntity reminder = reminder(fixture, activity, true, 60,
                activity.getStartAt().minusSeconds(3600));
        notificationService.registerDevice(fixture.member(), new RegisterDeviceRequest(
                "suppression-device-" + suppression, "ANDROID", "suppression-token-" + UUID.randomUUID()));
        switch (suppression) {
            case "global" -> notificationService.updateUserSettings(fixture.member(),
                    new UpdateUserNotificationSettingsRequest(false, null, null, null, null, null, null, null, null));
            case "category" -> notificationService.updateUserSettings(fixture.member(),
                    new UpdateUserNotificationSettingsRequest(null, null, null, null, false, null, null, null, null));
            case "mute" -> notificationService.updateGroupSettings(fixture.group(), fixture.member(),
                    new UpdateGroupNotificationSettingsRequest(true, "UNTIL_UNMUTED", null));
            default -> throw new IllegalArgumentException(suppression);
        }

        assertThat(scheduler.processDueBatch()).isEqualTo(1);
        assertThat(inbox(fixture.member())).hasSize(1);
        assertThat(reminders.findById(reminder.getId()).orElseThrow().getSentAt()).isNotNull();
        assertThat(pushGateway.messages).isEmpty();
    }

    private List<NotificationItemResponse> inbox(UUID userId) {
        return notificationService.listNotifications(userId, 0, 100).items();
    }

    private String reminderTestUsers() {
        return "(SELECT id FROM users WHERE email LIKE '%@m15-reminder.test')";
    }

    private Fixture fixture() {
        Instant now = Instant.now();
        UUID owner = user("owner", now);
        UUID member = user("member", now);
        UUID group = UUID.randomUUID();
        groups.saveAndFlush(new GroupEntity(group, "M15 Reminder " + group, null, null,
                GroupStatus.ACTIVE, owner, now, now));
        groupSettings.saveAndFlush(GroupSettingsEntity.createDefault(group, now));
        memberships.saveAndFlush(new GroupMembershipEntity(UUID.randomUUID(), group, owner,
                GroupRole.OWNER, GroupMembershipStatus.ACTIVE, now, null));
        memberships.saveAndFlush(new GroupMembershipEntity(UUID.randomUUID(), group, member,
                GroupRole.MEMBER, GroupMembershipStatus.ACTIVE, now, null));
        return new Fixture(owner, member, group);
    }

    private UUID user(String label, Instant now) {
        UUID id = UUID.randomUUID();
        users.saveAndFlush(new UserEntity(id, id + "+" + label + "@m15-reminder.test",
                "m15_reminder_" + label + "_" + id, label, UserStatus.ACTIVE, now, now));
        return id;
    }

    private ActivityEntity dueActivity(Fixture fixture) {
        return dueActivity(fixture, "due", ActivityStatus.CONFIRMED);
    }

    private ActivityEntity dueActivity(Fixture fixture, String title, ActivityStatus status) {
        return activity(fixture, title, status, Instant.now().plus(59, ChronoUnit.MINUTES));
    }

    private ActivityEntity activity(Fixture fixture, String title, ActivityStatus status, Instant startAt) {
        Instant now = Instant.now();
        ActivityEntity activity = new ActivityEntity(UUID.randomUUID(), fixture.group(), fixture.owner(),
                title + " " + UUID.randomUUID(), null, status, startAt, null, "UTC", null, null, now, now);
        return activities.saveAndFlush(activity);
    }

    private ActivityReminderEntity reminder(Fixture fixture, ActivityEntity activity, boolean enabled,
                                            int offsetMinutes, Instant remindAt) {
        Instant now = Instant.now();
        return reminders.saveAndFlush(new ActivityReminderEntity(UUID.randomUUID(), activity.getId(),
                fixture.member(), enabled, offsetMinutes, remindAt, now));
    }

    private record Fixture(UUID owner, UUID member, UUID group) { }
}
