package com.wedo.backend.user.entity;

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
@Table(name = "user_privacy_settings")
public class UserPrivacySettingsEntity {

    @Id
    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "discover_by_username", nullable = false)
    private boolean discoverByUsername = true;

    @Column(name = "discover_by_qr", nullable = false)
    private boolean discoverByQr = true;

    @Column(name = "discover_by_email", nullable = false)
    private boolean discoverByEmail = false;

    @Column(name = "discover_by_phone", nullable = false)
    private boolean discoverByPhone = false;

    @Enumerated(EnumType.STRING)
    @Column(name = "dm_policy", length = 30, nullable = false)
    private DmPolicy dmPolicy = DmPolicy.EVERYONE;

    @Enumerated(EnumType.STRING)
    @Column(name = "friend_request_policy", length = 30, nullable = false)
    private FriendRequestPolicy friendRequestPolicy = FriendRequestPolicy.EVERYONE;

    @Column(name = "show_online_status", nullable = false)
    private boolean showOnlineStatus = true;

    @Column(name = "show_last_seen", nullable = false)
    private boolean showLastSeen = true;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected UserPrivacySettingsEntity() {
    }

    public UserPrivacySettingsEntity(UUID userId, boolean discoverByUsername, boolean discoverByQr, boolean discoverByEmail, boolean discoverByPhone, DmPolicy dmPolicy, FriendRequestPolicy friendRequestPolicy, boolean showOnlineStatus, boolean showLastSeen, Instant createdAt, Instant updatedAt) {
        this.userId = userId;
        this.discoverByUsername = discoverByUsername;
        this.discoverByQr = discoverByQr;
        this.discoverByEmail = discoverByEmail;
        this.discoverByPhone = discoverByPhone;
        this.dmPolicy = dmPolicy;
        this.friendRequestPolicy = friendRequestPolicy;
        this.showOnlineStatus = showOnlineStatus;
        this.showLastSeen = showLastSeen;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
    }

    public static UserPrivacySettingsEntity createDefault(UUID userId, Instant now) {
        return new UserPrivacySettingsEntity(
                userId,
                true,
                true,
                false,
                false,
                DmPolicy.EVERYONE,
                FriendRequestPolicy.EVERYONE,
                true,
                true,
                now,
                now
        );
    }

    public UUID getUserId() {
        return userId;
    }

    public void setUserId(UUID userId) {
        this.userId = userId;
    }

    public boolean isDiscoverByUsername() {
        return discoverByUsername;
    }

    public void setDiscoverByUsername(boolean discoverByUsername) {
        this.discoverByUsername = discoverByUsername;
    }

    public boolean isDiscoverByQr() {
        return discoverByQr;
    }

    public void setDiscoverByQr(boolean discoverByQr) {
        this.discoverByQr = discoverByQr;
    }

    public boolean isDiscoverByEmail() {
        return discoverByEmail;
    }

    public void setDiscoverByEmail(boolean discoverByEmail) {
        this.discoverByEmail = discoverByEmail;
    }

    public boolean isDiscoverByPhone() {
        return discoverByPhone;
    }

    public void setDiscoverByPhone(boolean discoverByPhone) {
        this.discoverByPhone = discoverByPhone;
    }

    public DmPolicy getDmPolicy() {
        return dmPolicy;
    }

    public void setDmPolicy(DmPolicy dmPolicy) {
        this.dmPolicy = dmPolicy;
    }

    public FriendRequestPolicy getFriendRequestPolicy() {
        return friendRequestPolicy;
    }

    public void setFriendRequestPolicy(FriendRequestPolicy friendRequestPolicy) {
        this.friendRequestPolicy = friendRequestPolicy;
    }

    public boolean isShowOnlineStatus() {
        return showOnlineStatus;
    }

    public void setShowOnlineStatus(boolean showOnlineStatus) {
        this.showOnlineStatus = showOnlineStatus;
    }

    public boolean isShowLastSeen() {
        return showLastSeen;
    }

    public void setShowLastSeen(boolean showLastSeen) {
        this.showLastSeen = showLastSeen;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(Instant updatedAt) {
        this.updatedAt = updatedAt;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        UserPrivacySettingsEntity that = (UserPrivacySettingsEntity) o;
        return Objects.equals(userId, that.userId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(userId);
    }
}
