package com.wedo.backend.activity.reminder;

import com.wedo.backend.activity.entity.ActivityEntity;
import com.wedo.backend.activity.entity.ActivityStatus;
import com.wedo.backend.activity.repository.ActivityRepository;
import com.wedo.backend.activity.service.M8ActivityAccessService;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.notification.service.NotificationService;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

@Service
public class ActivityReminderDeliveryScheduler {
    private static final Logger log = LoggerFactory.getLogger(ActivityReminderDeliveryScheduler.class);

    private final JdbcTemplate jdbc;
    private final ActivityRepository activities;
    private final ActivityReminderRepository reminders;
    private final M8ActivityAccessService activityAccess;
    private final NotificationService notifications;
    private final Clock clock;
    private final TransactionTemplate transaction;
    private final int batchSize;

    public ActivityReminderDeliveryScheduler(
            JdbcTemplate jdbc,
            ActivityRepository activities,
            ActivityReminderRepository reminders,
            M8ActivityAccessService activityAccess,
            NotificationService notifications,
            Clock clock,
            PlatformTransactionManager transactionManager,
            @Value("${wedo.reminders.scheduler.batch-size:100}") int batchSize
    ) {
        this.jdbc = jdbc;
        this.activities = activities;
        this.reminders = reminders;
        this.activityAccess = activityAccess;
        this.notifications = notifications;
        this.clock = clock;
        this.transaction = new TransactionTemplate(transactionManager);
        this.batchSize = Math.max(1, batchSize);
    }

    @Scheduled(fixedDelayString = "${wedo.reminders.scheduler.fixed-delay-ms:45000}")
    public void scheduledTick() {
        processDueBatch();
    }

    public int processDueBatch() {
        Instant now = clock.instant();
        List<Candidate> candidates = jdbc.query("""
                SELECT r.id AS reminder_id, r.activity_id
                FROM user_activity_reminders r
                JOIN activities a ON a.id = r.activity_id
                JOIN groups g ON g.id = a.group_id AND g.status = 'ACTIVE'
                JOIN group_memberships gm ON gm.group_id = g.id
                    AND gm.user_id = r.user_id AND gm.status = 'ACTIVE'
                JOIN users u ON u.id = r.user_id AND u.status = 'ACTIVE'
                WHERE r.enabled = TRUE
                  AND r.sent_at IS NULL
                  AND r.remind_at <= ?
                  AND a.start_at > ?
                  AND a.status IN ('PLANNING', 'CONFIRMED')
                ORDER BY r.remind_at, r.id
                LIMIT ?
                """,
                (rs, rowNum) -> new Candidate(
                        rs.getObject("reminder_id", UUID.class),
                        rs.getObject("activity_id", UUID.class)),
                Timestamp.from(now),
                Timestamp.from(now),
                batchSize
        );

        int delivered = 0;
        for (Candidate candidate : candidates) {
            try {
                Boolean processed = transaction.execute(status -> processOne(candidate, now));
                if (Boolean.TRUE.equals(processed)) delivered++;
            } catch (RuntimeException ex) {
                log.warn("Activity reminder delivery transaction failed; it will be retried.");
            }
        }
        return delivered;
    }

    private Boolean processOne(Candidate candidate, Instant now) {
        ActivityEntity activity = activities.tryFindByIdForUpdateSkipLocked(candidate.activityId()).orElse(null);
        if (activity == null) return false;

        ActivityReminderEntity reminder = reminders.tryFindDueByIdForUpdateSkipLocked(
                candidate.reminderId(), candidate.activityId(), now).orElse(null);
        if (reminder == null || !isEligible(activity, now)) return false;

        try {
            var access = activityAccess.requireReadable(activity.getId(), reminder.getUserId());
            if (access.groupAccess().group().getStatus() != GroupStatus.ACTIVE) return false;
        } catch (BusinessException inaccessible) {
            return false;
        }

        Instant currentSchedule = activity.getStartAt().minusSeconds(
                Math.multiplyExact((long) reminder.getOffsetMinutes(), 60));
        if (!currentSchedule.equals(reminder.getRemindAt())) {
            reminder.reschedule(currentSchedule, now);
            if (currentSchedule.isAfter(now)) return false;
        }

        notifications.persistActivityReminder(
                reminder.getUserId(), activity.getId(), activity.getGroupId(), activity.getTitle(), currentSchedule);
        reminder.markSent(now);
        return true;
    }

    private boolean isEligible(ActivityEntity activity, Instant now) {
        return activity.getStartAt() != null
                && activity.getStartAt().isAfter(now)
                && (activity.getStatus() == ActivityStatus.PLANNING
                || activity.getStatus() == ActivityStatus.CONFIRMED);
    }

    private record Candidate(UUID reminderId, UUID activityId) { }
}
