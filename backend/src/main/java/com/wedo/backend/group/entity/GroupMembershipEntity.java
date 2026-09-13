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
@Table(name = "group_memberships")
public class GroupMembershipEntity {

    @Id
    @Column(name = "id", nullable = false)
    private UUID id;

    @Column(name = "group_id", nullable = false)
    private UUID groupId;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Enumerated(EnumType.STRING)
    @Column(name = "role", nullable = false, length = 30)
    private GroupRole role;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 30)
    private GroupMembershipStatus status;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "ended_at")
    private Instant endedAt;

    protected GroupMembershipEntity() {
    }

    public GroupMembershipEntity(UUID id, UUID groupId, UUID userId, GroupRole role, GroupMembershipStatus status, Instant createdAt, Instant endedAt) {
        this.id = id;
        this.groupId = groupId;
        this.userId = userId;
        this.role = role;
        this.status = status;
        this.createdAt = createdAt;
        this.endedAt = endedAt;
    }

    public UUID getGroupId() { return groupId; }
    public UUID getUserId() { return userId; }
    public GroupRole getRole() { return role; }
    public GroupMembershipStatus getStatus() { return status; }
    public Instant getEndedAt() { return endedAt; }
}
