package com.wedo.backend.group.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "group_join_requests")
public class GroupJoinRequestEntity {

    @Id
    @Column(name = "id", nullable = false)
    private UUID id;

    @Column(name = "group_id", nullable = false)
    private UUID groupId;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 30)
    private GroupJoinRequestStatus status;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "responded_at")
    private Instant respondedAt;

    @Column(name = "responded_by")
    private UUID respondedBy;

    protected GroupJoinRequestEntity() {
    }

    public GroupJoinRequestEntity(UUID id, UUID groupId, UUID userId, GroupJoinRequestStatus status, Instant createdAt, Instant respondedAt, UUID respondedBy) {
        this.id = id;
        this.groupId = groupId;
        this.userId = userId;
        this.status = status;
        this.createdAt = createdAt;
        this.respondedAt = respondedAt;
        this.respondedBy = respondedBy;
    }

    public UUID getId() { return id; }
    public UUID getGroupId() { return groupId; }
    public UUID getUserId() { return userId; }
    public GroupJoinRequestStatus getStatus() { return status; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getRespondedAt() { return respondedAt; }
    public UUID getRespondedBy() { return respondedBy; }

    public void approve(UUID responderId, Instant now) {
        requirePending();
        this.status = GroupJoinRequestStatus.APPROVED;
        this.respondedBy = responderId;
        this.respondedAt = now;
    }

    public void reject(UUID responderId, Instant now) {
        requirePending();
        this.status = GroupJoinRequestStatus.REJECTED;
        this.respondedBy = responderId;
        this.respondedAt = now;
    }

    public void cancel(Instant now) {
        requirePending();
        this.status = GroupJoinRequestStatus.CANCELLED;
        this.respondedBy = null;
        this.respondedAt = now;
    }

    private void requirePending() {
        if (this.status != GroupJoinRequestStatus.PENDING) {
            throw new IllegalStateException("Join request is already resolved");
        }
    }
}
