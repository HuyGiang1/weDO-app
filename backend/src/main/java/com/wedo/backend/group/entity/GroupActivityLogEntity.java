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
@Table(name = "group_activity_logs")
public class GroupActivityLogEntity {

    @Id
    @Column(name = "id", nullable = false)
    private UUID id;

    @Column(name = "group_id", nullable = false)
    private UUID groupId;

    @Column(name = "actor_id")
    private UUID actorId;

    @Enumerated(EnumType.STRING)
    @Column(name = "action", nullable = false, length = 50)
    private GroupActivityAction action;

    @Column(name = "target_user_id")
    private UUID targetUserId;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected GroupActivityLogEntity() {
    }

    public GroupActivityLogEntity(UUID id, UUID groupId, UUID actorId, GroupActivityAction action, Instant createdAt) {
        this(id, groupId, actorId, action, null, createdAt);
    }

    public GroupActivityLogEntity(UUID id, UUID groupId, UUID actorId, GroupActivityAction action, UUID targetUserId, Instant createdAt) {
        this.id = id;
        this.groupId = groupId;
        this.actorId = actorId;
        this.action = action;
        this.targetUserId = targetUserId;
        this.createdAt = createdAt;
    }

    public UUID getGroupId() { return groupId; }
    public UUID getActorId() { return actorId; }
    public GroupActivityAction getAction() { return action; }
    public UUID getTargetUserId() { return targetUserId; }
}
