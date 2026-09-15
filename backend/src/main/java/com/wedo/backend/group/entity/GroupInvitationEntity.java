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
@Table(name = "group_invitations")
public class GroupInvitationEntity {

    @Id
    @Column(name = "id", nullable = false)
    private UUID id;

    @Column(name = "group_id", nullable = false)
    private UUID groupId;

    @Column(name = "inviter_id")
    private UUID inviterId;

    @Column(name = "invitee_id", nullable = false)
    private UUID inviteeId;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 30)
    private GroupInvitationStatus status;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "responded_at")
    private Instant respondedAt;

    protected GroupInvitationEntity() {
    }

    public GroupInvitationEntity(UUID id, UUID groupId, UUID inviterId, UUID inviteeId, GroupInvitationStatus status, Instant createdAt, Instant respondedAt) {
        this.id = id;
        this.groupId = groupId;
        this.inviterId = inviterId;
        this.inviteeId = inviteeId;
        this.status = status;
        this.createdAt = createdAt;
        this.respondedAt = respondedAt;
    }

    public UUID getId() { return id; }
    public UUID getGroupId() { return groupId; }
    public UUID getInviterId() { return inviterId; }
    public UUID getInviteeId() { return inviteeId; }
    public GroupInvitationStatus getStatus() { return status; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getRespondedAt() { return respondedAt; }

    public void accept(Instant now) {
        requirePending();
        this.status = GroupInvitationStatus.ACCEPTED;
        this.respondedAt = now;
    }

    public void decline(Instant now) {
        requirePending();
        this.status = GroupInvitationStatus.DECLINED;
        this.respondedAt = now;
    }

    public void cancel(Instant now) {
        requirePending();
        this.status = GroupInvitationStatus.CANCELLED;
        this.respondedAt = now;
    }

    private void requirePending() {
        if (this.status != GroupInvitationStatus.PENDING) {
            throw new IllegalStateException("Invitation is already resolved");
        }
    }
}
