package com.wedo.backend.auth.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

@Entity
@Table(name = "refresh_sessions")
public class RefreshSessionEntity {

    @Id
    @Column(name = "id", nullable = false)
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "token_hash", length = 255, nullable = false, unique = true)
    private String tokenHash;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(name = "revoked_at")
    private Instant revokedAt;

    @Column(name = "replaced_by_session_id")
    private UUID replacedBySessionId;

    @Column(name = "device_name", length = 100)
    private String deviceName;

    @Column(name = "ip_address", length = 45)
    private String ipAddress;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected RefreshSessionEntity() {
    }

    public RefreshSessionEntity(UUID id, UUID userId, String tokenHash, Instant expiresAt, Instant revokedAt, UUID replacedBySessionId, String deviceName, String ipAddress, Instant createdAt) {
        this.id = id;
        this.userId = userId;
        this.tokenHash = tokenHash;
        this.expiresAt = expiresAt;
        this.revokedAt = revokedAt;
        this.replacedBySessionId = replacedBySessionId;
        this.deviceName = deviceName;
        this.ipAddress = ipAddress;
        this.createdAt = createdAt;
    }

    public UUID getId() {
        return id;
    }

    public void setId(UUID id) {
        this.id = id;
    }

    public UUID getUserId() {
        return userId;
    }

    public void setUserId(UUID userId) {
        this.userId = userId;
    }

    public String getTokenHash() {
        return tokenHash;
    }

    public void setTokenHash(String tokenHash) {
        this.tokenHash = tokenHash;
    }

    public Instant getExpiresAt() {
        return expiresAt;
    }

    public void setExpiresAt(Instant expiresAt) {
        this.expiresAt = expiresAt;
    }

    public Instant getRevokedAt() {
        return revokedAt;
    }

    public void setRevokedAt(Instant revokedAt) {
        this.revokedAt = revokedAt;
    }

    public UUID getReplacedBySessionId() {
        return replacedBySessionId;
    }

    public void setReplacedBySessionId(UUID replacedBySessionId) {
        this.replacedBySessionId = replacedBySessionId;
    }

    public String getDeviceName() {
        return deviceName;
    }

    public void setDeviceName(String deviceName) {
        this.deviceName = deviceName;
    }

    public String getIpAddress() {
        return ipAddress;
    }

    public void setIpAddress(String ipAddress) {
        this.ipAddress = ipAddress;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        RefreshSessionEntity that = (RefreshSessionEntity) o;
        return Objects.equals(id, that.id);
    }

    @Override
    public int hashCode() {
        return Objects.hash(id);
    }
}
