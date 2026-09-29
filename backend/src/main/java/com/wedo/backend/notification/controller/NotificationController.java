package com.wedo.backend.notification.controller;

import com.wedo.backend.common.dto.PagedResponse;
import com.wedo.backend.notification.dto.NotificationDtos.GroupNotificationSettingsResponse;
import com.wedo.backend.notification.dto.NotificationDtos.MarkAllReadResponse;
import com.wedo.backend.notification.dto.NotificationDtos.NotificationItemResponse;
import com.wedo.backend.notification.dto.NotificationDtos.RegisterDeviceRequest;
import com.wedo.backend.notification.dto.NotificationDtos.UnreadCountResponse;
import com.wedo.backend.notification.dto.NotificationDtos.UpdateGroupNotificationSettingsRequest;
import com.wedo.backend.notification.dto.NotificationDtos.UpdateUserNotificationSettingsRequest;
import com.wedo.backend.notification.dto.NotificationDtos.UserDeviceResponse;
import com.wedo.backend.notification.dto.NotificationDtos.UserNotificationSettingsResponse;
import com.wedo.backend.notification.service.NotificationService;
import com.wedo.backend.security.AuthenticatedUserPrincipal;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
@Validated
public class NotificationController {

    private final NotificationService notificationService;

    public NotificationController(NotificationService notificationService) {
        this.notificationService = notificationService;
    }

    @GetMapping("/notifications")
    public PagedResponse<NotificationItemResponse> listNotifications(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "30") int size
    ) {
        return notificationService.listNotifications(principal.userId(), page, size);
    }

    @GetMapping("/notifications/unread-count")
    public UnreadCountResponse getUnreadCount(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal
    ) {
        return notificationService.getUnreadCount(principal.userId());
    }

    @PostMapping("/notifications/{notificationId}/read")
    public NotificationItemResponse markRead(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID notificationId
    ) {
        return notificationService.markRead(notificationId, principal.userId());
    }

    @PostMapping("/notifications/read-all")
    public MarkAllReadResponse markAllRead(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal
    ) {
        return notificationService.markAllRead(principal.userId());
    }

    @GetMapping("/me/notification-settings")
    public UserNotificationSettingsResponse getMyNotificationSettings(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal
    ) {
        return notificationService.getUserSettings(principal.userId());
    }

    @PatchMapping("/me/notification-settings")
    public UserNotificationSettingsResponse updateMyNotificationSettings(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @Valid @RequestBody UpdateUserNotificationSettingsRequest request
    ) {
        return notificationService.updateUserSettings(principal.userId(), request);
    }

    @GetMapping("/groups/{groupId}/notification-settings")
    public GroupNotificationSettingsResponse getGroupNotificationSettings(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID groupId
    ) {
        return notificationService.getGroupSettings(groupId, principal.userId());
    }

    @PutMapping("/groups/{groupId}/notification-settings")
    public GroupNotificationSettingsResponse updateGroupNotificationSettings(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID groupId,
            @Valid @RequestBody UpdateGroupNotificationSettingsRequest request
    ) {
        return notificationService.updateGroupSettings(groupId, principal.userId(), request);
    }

    @GetMapping("/me/devices")
    public List<UserDeviceResponse> listMyDevices(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal
    ) {
        return notificationService.listDevices(principal.userId());
    }

    @PostMapping("/me/devices")
    @ResponseStatus(HttpStatus.CREATED)
    public UserDeviceResponse registerMyDevice(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @Valid @RequestBody RegisterDeviceRequest request
    ) {
        return notificationService.registerDevice(principal.userId(), request);
    }

    @DeleteMapping("/me/devices/{deviceId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deactivateMyDevice(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable String deviceId
    ) {
        notificationService.deactivateDevice(principal.userId(), deviceId);
    }
}
