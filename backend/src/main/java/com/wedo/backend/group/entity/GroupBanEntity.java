package com.wedo.backend.group.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "group_bans")
public class GroupBanEntity {

    @Id
    @Column(name = "id", nullable = false)
    private UUID id;

    @Column(name = "group_id", nullable = false)
    private UUID groupId;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "banned_by")
    private UUID bannedBy;

    @Column(name = "reason", length = 500)
    private String reason;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "unbanned_at")
    private Instant unbannedAt;

    protected GroupBanEntity() {
    }

    public GroupBanEntity(UUID id, UUID groupId, UUID userId, UUID bannedBy, String reason, Instant createdAt, Instant unbannedAt) {
        this.id = id;
        this.groupId = groupId;
        this.userId = userId;
        this.bannedBy = bannedBy;
        this.reason = reason;
        this.createdAt = createdAt;
        this.unbannedAt = unbannedAt;
    }

    public UUID getId() { return id; }
    public UUID getGroupId() { return groupId; }
    public UUID getUserId() { return userId; }
    public UUID getBannedBy() { return bannedBy; }
    public String getReason() { return reason; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getUnbannedAt() { return unbannedAt; }

    public boolean isActive() {
        return unbannedAt == null;
    }

    public void unban(Instant now) {
        if (unbannedAt != null) {
            throw new IllegalStateException("User is not currently banned");
        }
        this.unbannedAt = now;
    }
}
