package com.wedo.backend.notification.dto;

import jakarta.validation.constraints.NotBlank;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;

public final class NotificationDtos {

    private NotificationDtos() {
    }

    public record NotificationActorSummary(
            UUID id,
            String displayName,
            String avatarStorageKey
    ) {
    }

    public record NotificationGroupSummary(
            UUID id,
            String name,
            String status
    ) {
    }

    public record NotificationTargetInfo(
            String targetType,
            UUID targetId,
            String route,
            boolean actionable,
            String nonActionableReason,
            Map<String, Object> params
    ) {
    }

    public record NotificationItemResponse(
            UUID id,
            String category,
            String priority,
            boolean critical,
            String title,
            String body,
            NotificationActorSummary actor,
            NotificationGroupSummary group,
            NotificationTargetInfo target,
            boolean read,
            Instant readAt,
            Instant createdAt
    ) {
    }

    public record UnreadCountResponse(
            long unreadCount
    ) {
    }

    public record MarkAllReadResponse(
            int markedCount,
            long unreadCount
    ) {
    }

    public record UserNotificationSettingsResponse(
            boolean pushEnabled,
            boolean socialEnabled,
            boolean groupEnabled,
            boolean chatEnabled,
            boolean activityEnabled,
            boolean pollEnabled,
            boolean taskEnabled,
            boolean financeEnabled,
            boolean fundEnabled,
            Instant updatedAt
    ) {
    }

    public record UpdateUserNotificationSettingsRequest(
            Boolean pushEnabled,
            Boolean socialEnabled,
            Boolean groupEnabled,
            Boolean chatEnabled,
            Boolean activityEnabled,
            Boolean pollEnabled,
            Boolean taskEnabled,
            Boolean financeEnabled,
            Boolean fundEnabled
    ) {
    }

    public record GroupNotificationSettingsResponse(
            UUID groupId,
            boolean muted,
            boolean effectivelyMuted,
            String muteOption,
            Instant mutedUntil,
            Instant updatedAt
    ) {
    }

    public record UpdateGroupNotificationSettingsRequest(
            Boolean muted,
            String duration,
            Instant mutedUntil
    ) {
    }

    public record RegisterDeviceRequest(
            @NotBlank(message = "deviceId is required.")
            String deviceId,
            @NotBlank(message = "platform is required.")
            String platform,
            @NotBlank(message = "pushToken is required.")
            String pushToken
    ) {
    }

    public record UserDeviceResponse(
            UUID id,
            UUID userId,
            String deviceId,
            String platform,
            String pushToken,
            boolean active,
            Instant lastSeenAt,
            Instant updatedAt
    ) {
    }
}
