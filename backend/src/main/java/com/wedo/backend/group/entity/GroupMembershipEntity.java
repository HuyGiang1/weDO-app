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

    public UUID getId() { return id; }
    public UUID getGroupId() { return groupId; }
    public UUID getUserId() { return userId; }
    public GroupRole getRole() { return role; }
    public GroupMembershipStatus getStatus() { return status; }
    public Instant getEndedAt() { return endedAt; }

    public void promoteToAdmin() { requireActiveRole(GroupRole.MEMBER); this.role = GroupRole.ADMIN; }
    public void demoteToMember() { requireActiveRole(GroupRole.ADMIN); this.role = GroupRole.MEMBER; }
    public void transferOwnerToAdmin() { requireActiveRole(GroupRole.OWNER); this.role = GroupRole.ADMIN; }
    public void transferToOwner() {
        if (status != GroupMembershipStatus.ACTIVE || (role != GroupRole.MEMBER && role != GroupRole.ADMIN)) throw new IllegalStateException("Invalid ownership target");
        this.role = GroupRole.OWNER;
    }
    public void endAsLeft(Instant now) { end(GroupMembershipStatus.LEFT, now); }
    public void endAsKicked(Instant now) { end(GroupMembershipStatus.KICKED, now); }
    public void endAsBanned(Instant now) { end(GroupMembershipStatus.BANNED, now); }
    private void requireActiveRole(GroupRole expected) {
        if (status != GroupMembershipStatus.ACTIVE || role != expected) throw new IllegalStateException("Invalid group role transition");
    }
    private void end(GroupMembershipStatus endingStatus, Instant now) {
        if (status != GroupMembershipStatus.ACTIVE) throw new IllegalStateException("Membership is not active");
        this.status = endingStatus;
        this.endedAt = now;
    }
}
