package com.wedo.backend.group.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "group_invite_links")
public class GroupInviteLinkEntity {

    @Id
    @Column(name = "id", nullable = false)
    private UUID id;

    @Column(name = "group_id", nullable = false)
    private UUID groupId;

    @Column(name = "code", nullable = false, unique = true, length = 50)
    private String code;

    @Column(name = "created_by")
    private UUID createdBy;

    @Column(name = "max_uses")
    private Integer maxUses;

    @Column(name = "uses_count", nullable = false)
    private int usesCount;

    @Column(name = "expires_at")
    private Instant expiresAt;

    @Column(name = "is_revoked", nullable = false)
    private boolean isRevoked;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected GroupInviteLinkEntity() {
    }

    public GroupInviteLinkEntity(UUID id, UUID groupId, String code, UUID createdBy, Integer maxUses, int usesCount, Instant expiresAt, boolean isRevoked, Instant createdAt) {
        this.id = id;
        this.groupId = groupId;
        this.code = code;
        this.createdBy = createdBy;
        this.maxUses = maxUses;
        this.usesCount = usesCount;
        this.expiresAt = expiresAt;
        this.isRevoked = isRevoked;
        this.createdAt = createdAt;
    }

    public UUID getId() { return id; }
    public UUID getGroupId() { return groupId; }
    public String getCode() { return code; }
    public UUID getCreatedBy() { return createdBy; }
    public Integer getMaxUses() { return maxUses; }
    public int getUsesCount() { return usesCount; }
    public Instant getExpiresAt() { return expiresAt; }
    public boolean isRevoked() { return isRevoked; }
    public Instant getCreatedAt() { return createdAt; }

    public void revoke() {
        this.isRevoked = true;
    }

    public void incrementUses() {
        if (maxUses != null && usesCount >= maxUses) {
            throw new IllegalStateException("Invite link usage limit reached");
        }
        this.usesCount++;
    }

    public boolean isExpired(Instant now) {
        return expiresAt != null && now.isAfter(expiresAt);
    }

    public boolean isLimitReached() {
        return maxUses != null && usesCount >= maxUses;
    }
}
