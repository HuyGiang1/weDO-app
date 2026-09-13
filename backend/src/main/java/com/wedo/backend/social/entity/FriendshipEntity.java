package com.wedo.backend.social.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

@Entity
@Table(name = "friendships")
public class FriendshipEntity {

    @Id
    @Column(name = "id", nullable = false)
    private UUID id;

    @Column(name = "user_id_1", nullable = false)
    private UUID userId1;

    @Column(name = "user_id_2", nullable = false)
    private UUID userId2;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", length = 30, nullable = false)
    private FriendshipStatus status;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "ended_at")
    private Instant endedAt;

    protected FriendshipEntity() {
    }

    public FriendshipEntity(UUID id, UUID userId1, UUID userId2, FriendshipStatus status, Instant createdAt, Instant endedAt) {
        if (userId1.compareTo(userId2) >= 0) {
            throw new IllegalArgumentException("Canonical pair violation: userId1 must be strictly less than userId2");
        }
        this.id = id;
        this.userId1 = userId1;
        this.userId2 = userId2;
        this.status = status;
        this.createdAt = createdAt;
        this.endedAt = endedAt;
    }

    public static FriendshipEntity createActive(UUID id, UUID userA, UUID userB, Instant now) {
        UUID u1 = userA.compareTo(userB) < 0 ? userA : userB;
        UUID u2 = userA.compareTo(userB) < 0 ? userB : userA;
        return new FriendshipEntity(id, u1, u2, FriendshipStatus.ACTIVE, now, null);
    }

    public UUID getId() {
        return id;
    }

    public void setId(UUID id) {
        this.id = id;
    }

    public UUID getUserId1() {
        return userId1;
    }

    public void setUserId1(UUID userId1) {
        this.userId1 = userId1;
    }

    public UUID getUserId2() {
        return userId2;
    }

    public void setUserId2(UUID userId2) {
        this.userId2 = userId2;
    }

    public FriendshipStatus getStatus() {
        return status;
    }

    public void setStatus(FriendshipStatus status) {
        this.status = status;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public Instant getEndedAt() {
        return endedAt;
    }

    public void setEndedAt(Instant endedAt) {
        this.endedAt = endedAt;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        FriendshipEntity that = (FriendshipEntity) o;
        return Objects.equals(id, that.id);
    }

    @Override
    public int hashCode() {
        return Objects.hash(id);
    }
}
