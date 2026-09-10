package com.wedo.backend.notification.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

@Entity
@Table(name = "user_notification_settings")
public class UserNotificationSettingsEntity {

    @Id
    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "push_enabled", nullable = false)
    private boolean pushEnabled = true;

    @Column(name = "social_enabled", nullable = false)
    private boolean socialEnabled = true;

    @Column(name = "group_enabled", nullable = false)
    private boolean groupEnabled = true;

    @Column(name = "chat_enabled", nullable = false)
    private boolean chatEnabled = true;

    @Column(name = "activity_enabled", nullable = false)
    private boolean activityEnabled = true;

    @Column(name = "poll_enabled", nullable = false)
    private boolean pollEnabled = true;

    @Column(name = "task_enabled", nullable = false)
    private boolean taskEnabled = true;

    @Column(name = "finance_enabled", nullable = false)
    private boolean financeEnabled = true;

    @Column(name = "fund_enabled", nullable = false)
    private boolean fundEnabled = true;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected UserNotificationSettingsEntity() {
    }

    public UserNotificationSettingsEntity(UUID userId, boolean pushEnabled, boolean socialEnabled, boolean groupEnabled, boolean chatEnabled, boolean activityEnabled, boolean pollEnabled, boolean taskEnabled, boolean financeEnabled, boolean fundEnabled, Instant createdAt, Instant updatedAt) {
        this.userId = userId;
        this.pushEnabled = pushEnabled;
        this.socialEnabled = socialEnabled;
        this.groupEnabled = groupEnabled;
        this.chatEnabled = chatEnabled;
        this.activityEnabled = activityEnabled;
        this.pollEnabled = pollEnabled;
        this.taskEnabled = taskEnabled;
        this.financeEnabled = financeEnabled;
        this.fundEnabled = fundEnabled;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
    }

    public static UserNotificationSettingsEntity createDefault(UUID userId, Instant now) {
        return new UserNotificationSettingsEntity(
                userId,
                true,
                true,
                true,
                true,
                true,
                true,
                true,
                true,
                true,
                now,
                now
        );
    }

    public UUID getUserId() {
        return userId;
    }

    public void setUserId(UUID userId) {
        this.userId = userId;
    }

    public boolean isPushEnabled() {
        return pushEnabled;
    }

    public void setPushEnabled(boolean pushEnabled) {
        this.pushEnabled = pushEnabled;
    }

    public boolean isSocialEnabled() {
        return socialEnabled;
    }

    public void setSocialEnabled(boolean socialEnabled) {
        this.socialEnabled = socialEnabled;
    }

    public boolean isGroupEnabled() {
        return groupEnabled;
    }

    public void setGroupEnabled(boolean groupEnabled) {
        this.groupEnabled = groupEnabled;
    }

    public boolean isChatEnabled() {
        return chatEnabled;
    }

    public void setChatEnabled(boolean chatEnabled) {
        this.chatEnabled = chatEnabled;
    }

    public boolean isActivityEnabled() {
        return activityEnabled;
    }

    public void setActivityEnabled(boolean activityEnabled) {
        this.activityEnabled = activityEnabled;
    }

    public boolean isPollEnabled() {
        return pollEnabled;
    }

    public void setPollEnabled(boolean pollEnabled) {
        this.pollEnabled = pollEnabled;
    }

    public boolean isTaskEnabled() {
        return taskEnabled;
    }

    public void setTaskEnabled(boolean taskEnabled) {
        this.taskEnabled = taskEnabled;
    }

    public boolean isFinanceEnabled() {
        return financeEnabled;
    }

    public void setFinanceEnabled(boolean financeEnabled) {
        this.financeEnabled = financeEnabled;
    }

    public boolean isFundEnabled() {
        return fundEnabled;
    }

    public void setFundEnabled(boolean fundEnabled) {
        this.fundEnabled = fundEnabled;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(Instant updatedAt) {
        this.updatedAt = updatedAt;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        UserNotificationSettingsEntity that = (UserNotificationSettingsEntity) o;
        return Objects.equals(userId, that.userId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(userId);
    }
}
