package com.wedo.backend.group.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.Instant;
import java.util.UUID;
import java.util.Objects;

@Entity
@Table(name = "groups")
public class GroupEntity {

    @Id
    @Column(name = "id", nullable = false)
    private UUID id;

    @Column(name = "name", nullable = false, length = 100)
    private String name;

    @Column(name = "description", length = 500)
    private String description;

    @Column(name = "avatar_storage_key", length = 255)
    private String avatarStorageKey;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 30)
    private GroupStatus status;

    @Column(name = "created_by", nullable = false)
    private UUID createdBy;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected GroupEntity() {
    }

    public GroupEntity(UUID id, String name, String description, String avatarStorageKey, GroupStatus status, UUID createdBy, Instant createdAt, Instant updatedAt) {
        this.id = id;
        this.name = name;
        this.description = description;
        this.avatarStorageKey = avatarStorageKey;
        this.status = status;
        this.createdBy = createdBy;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
    }

    public UUID getId() { return id; }
    public String getName() { return name; }
    public String getDescription() { return description; }
    public String getAvatarStorageKey() { return avatarStorageKey; }
    public GroupStatus getStatus() { return status; }
    public UUID getCreatedBy() { return createdBy; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }

    public boolean updateMetadata(String name, String description, String avatarStorageKey, Instant now) {
        if (Objects.equals(this.name, name)
                && Objects.equals(this.description, description)
                && Objects.equals(this.avatarStorageKey, avatarStorageKey)) {
            return false;
        }
        this.name = name;
        this.description = description;
        this.avatarStorageKey = avatarStorageKey;
        this.updatedAt = now;
        return true;
    }

    public void archive(Instant now) {
        if (this.status != GroupStatus.ACTIVE) {
            throw new IllegalStateException("Group is not active");
        }
        this.status = GroupStatus.ARCHIVED;
        this.updatedAt = now;
    }

    public void restore(Instant now) {
        if (this.status != GroupStatus.ARCHIVED) {
            throw new IllegalStateException("Group is not archived");
        }
        this.status = GroupStatus.ACTIVE;
        this.updatedAt = now;
    }

    public void delete(Instant now) {
        if (this.status == GroupStatus.DELETED) {
            throw new IllegalStateException("Group is already deleted");
        }
        this.status = GroupStatus.DELETED;
        this.updatedAt = now;
    }
}
