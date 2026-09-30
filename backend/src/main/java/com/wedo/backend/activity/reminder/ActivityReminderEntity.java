package com.wedo.backend.activity.reminder;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "user_activity_reminders")
public class ActivityReminderEntity {
    @Id
    private UUID id;
    @Column(name = "activity_id", nullable = false)
    private UUID activityId;
    @Column(name = "user_id", nullable = false)
    private UUID userId;
    @Column(nullable = false)
    private boolean enabled;
    @Column(name = "offset_minutes", nullable = false)
    private int offsetMinutes;
    @Column(name = "remind_at", nullable = false)
    private Instant remindAt;
    @Column(name = "sent_at")
    private Instant sentAt;
    @Column(name = "created_at", nullable = false)
    private Instant createdAt;
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected ActivityReminderEntity() { }

    public ActivityReminderEntity(UUID id, UUID activityId, UUID userId, boolean enabled,
                                 int offsetMinutes, Instant remindAt, Instant now) {
        this.id = id;
        this.activityId = activityId;
        this.userId = userId;
        this.enabled = enabled;
        this.offsetMinutes = offsetMinutes;
        this.remindAt = remindAt;
        this.createdAt = now;
        this.updatedAt = now;
    }

    public UUID getId() { return id; }
    public UUID getActivityId() { return activityId; }
    public UUID getUserId() { return userId; }
    public boolean isEnabled() { return enabled; }
    public int getOffsetMinutes() { return offsetMinutes; }
    public Instant getRemindAt() { return remindAt; }
    public Instant getSentAt() { return sentAt; }

    public void configure(boolean enabled, int offsetMinutes, Instant remindAt, boolean rearm, Instant now) {
        this.enabled = enabled;
        this.offsetMinutes = offsetMinutes;
        this.remindAt = remindAt;
        if (rearm) this.sentAt = null;
        this.updatedAt = now;
    }

    public void reschedule(Instant remindAt, Instant now) {
        this.remindAt = remindAt;
        this.updatedAt = now;
    }

    public void markSent(Instant now) {
        this.sentAt = now;
        this.updatedAt = now;
    }
}
