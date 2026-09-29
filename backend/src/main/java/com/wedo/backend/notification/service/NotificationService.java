package com.wedo.backend.notification.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.wedo.backend.chat.realtime.ChatRealtimeCoordinator;
import com.wedo.backend.chat.realtime.ChatRealtimeEvents;
import com.wedo.backend.common.dto.PagedResponse;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.group.service.GroupPermissionService;
import com.wedo.backend.notification.dto.NotificationDtos.GroupNotificationSettingsResponse;
import com.wedo.backend.notification.dto.NotificationDtos.MarkAllReadResponse;
import com.wedo.backend.notification.dto.NotificationDtos.NotificationActorSummary;
import com.wedo.backend.notification.dto.NotificationDtos.NotificationGroupSummary;
import com.wedo.backend.notification.dto.NotificationDtos.NotificationItemResponse;
import com.wedo.backend.notification.dto.NotificationDtos.NotificationTargetInfo;
import com.wedo.backend.notification.dto.NotificationDtos.RegisterDeviceRequest;
import com.wedo.backend.notification.dto.NotificationDtos.UnreadCountResponse;
import com.wedo.backend.notification.dto.NotificationDtos.UpdateGroupNotificationSettingsRequest;
import com.wedo.backend.notification.dto.NotificationDtos.UpdateUserNotificationSettingsRequest;
import com.wedo.backend.notification.dto.NotificationDtos.UserDeviceResponse;
import com.wedo.backend.notification.dto.NotificationDtos.UserNotificationSettingsResponse;
import com.wedo.backend.notification.entity.UserNotificationSettingsEntity;
import com.wedo.backend.notification.event.NotificationDomainEvent;
import com.wedo.backend.notification.push.PushGateway;
import com.wedo.backend.notification.push.PushGateway.PushDeliveryResult;
import com.wedo.backend.notification.push.PushGateway.PushDeliveryStatus;
import com.wedo.backend.notification.push.PushGateway.PushMessage;
import com.wedo.backend.notification.repository.UserNotificationSettingsRepository;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

@Service
public class NotificationService {

    public static final Set<String> VALID_CATEGORIES = Set.of(
            "SOCIAL", "GROUP", "CHAT", "ACTIVITY", "POLL", "TASK", "FINANCE", "FUND"
    );
    public static final Set<String> VALID_PRIORITIES = Set.of("HIGH", "NORMAL", "LOW");
    public static final Set<String> VALID_PLATFORMS = Set.of("ANDROID", "IOS", "WEB");

    private final JdbcTemplate jdbc;
    private final UserNotificationSettingsRepository userSettingsRepository;
    private final GroupPermissionService groupPermissionService;
    private final ChatRealtimeCoordinator chatRealtimeCoordinator;
    private final PushGateway pushGateway;
    private final ObjectMapper objectMapper;
    private final Clock clock;
    private final TransactionTemplate requiresNewTx;


    public NotificationService(
            JdbcTemplate jdbc,
            UserNotificationSettingsRepository userSettingsRepository,
            GroupPermissionService groupPermissionService,
            ChatRealtimeCoordinator chatRealtimeCoordinator,
            PushGateway pushGateway,
            ObjectMapper objectMapper,
            Clock clock,
            PlatformTransactionManager transactionManager
    ) {
        this.jdbc = jdbc;
        this.userSettingsRepository = userSettingsRepository;
        this.groupPermissionService = groupPermissionService;
        this.chatRealtimeCoordinator = chatRealtimeCoordinator;
        this.pushGateway = pushGateway;
        this.objectMapper = objectMapper;
        this.clock = clock;
        this.requiresNewTx = new TransactionTemplate(transactionManager);
        this.requiresNewTx.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
    }

    // =========================================================================
    // NOTI-01..04: Notification Center, Unread Count, Mark Read, Mark All Read
    // =========================================================================

    @Transactional(readOnly = true)
    public PagedResponse<NotificationItemResponse> listNotifications(UUID userId, int page, int size) {
        int safePage = Math.max(0, page);
        int safeSize = Math.max(1, Math.min(100, size));
        long total = queryTotalCount(userId);
        List<NotificationRow> rows = jdbc.query("""
                SELECT n.*,
                       u.display_name AS actor_display_name,
                       u.username AS actor_username,
                       u.avatar_storage_key AS actor_avatar,
                       g.name AS group_name,
                       g.status AS group_status
                FROM notifications n
                LEFT JOIN users u ON u.id = n.actor_id
                LEFT JOIN groups g ON g.id = n.group_id
                WHERE n.user_id = ?
                ORDER BY n.created_at DESC, n.id DESC
                LIMIT ? OFFSET ?
                """,
                this::mapNotificationRow,
                userId,
                safeSize,
                (long) safePage * safeSize
        );
        List<NotificationItemResponse> items = rows.stream()
                .map(row -> toNotificationItemResponse(row, userId))
                .toList();
        return PagedResponse.from(new PageImpl<>(items, PageRequest.of(safePage, safeSize), total), items);
    }

    @Transactional(readOnly = true)
    public UnreadCountResponse getUnreadCount(UUID userId) {
        Long count = jdbc.queryForObject(
                "SELECT count(*) FROM notifications WHERE user_id = ? AND read_at IS NULL",
                Long.class,
                userId
        );
        return new UnreadCountResponse(count == null ? 0L : count);
    }

    @Transactional
    public NotificationItemResponse markRead(UUID notificationId, UUID userId) {
        List<NotificationRow> rows = jdbc.query("""
                SELECT n.*,
                       u.display_name AS actor_display_name,
                       u.username AS actor_username,
                       u.avatar_storage_key AS actor_avatar,
                       g.name AS group_name,
                       g.status AS group_status
                FROM notifications n
                LEFT JOIN users u ON u.id = n.actor_id
                LEFT JOIN groups g ON g.id = n.group_id
                WHERE n.id = ?
                """,
                this::mapNotificationRow,
                notificationId
        );
        if (rows.isEmpty() || !userId.equals(rows.get(0).userId())) {
            throw new BusinessException(ErrorCode.NOTIFICATION_NOT_FOUND);
        }
        NotificationRow existing = rows.get(0);
        if (existing.readAt() == null) {
            Instant now = clock.instant().truncatedTo(java.time.temporal.ChronoUnit.MICROS);
            jdbc.update(
                    "UPDATE notifications SET read_at = ? WHERE id = ? AND user_id = ? AND read_at IS NULL",
                    Timestamp.from(now),
                    notificationId,
                    userId
            );
            existing = existing.withReadAt(now);
        }
        return toNotificationItemResponse(existing, userId);
    }

    @Transactional
    public MarkAllReadResponse markAllRead(UUID userId) {
        Instant now = clock.instant();
        int marked = jdbc.update(
                "UPDATE notifications SET read_at = ? WHERE user_id = ? AND read_at IS NULL",
                Timestamp.from(now),
                userId
        );
        long remaining = getUnreadCount(userId).unreadCount();
        return new MarkAllReadResponse(marked, remaining);
    }

    // =========================================================================
    // NOTI-05: User Notification Settings
    // =========================================================================

    @Transactional
    public UserNotificationSettingsResponse getUserSettings(UUID userId) {
        UserNotificationSettingsEntity entity = getOrCreateUserSettings(userId);
        return toUserSettingsResponse(entity);
    }

    @Transactional
    public UserNotificationSettingsResponse updateUserSettings(
            UUID userId,
            UpdateUserNotificationSettingsRequest request
    ) {
        UserNotificationSettingsEntity entity = getOrCreateUserSettings(userId);
        if (request != null) {
            if (request.pushEnabled() != null) entity.setPushEnabled(request.pushEnabled());
            if (request.socialEnabled() != null) entity.setSocialEnabled(request.socialEnabled());
            if (request.groupEnabled() != null) entity.setGroupEnabled(request.groupEnabled());
            if (request.chatEnabled() != null) entity.setChatEnabled(request.chatEnabled());
            if (request.activityEnabled() != null) entity.setActivityEnabled(request.activityEnabled());
            if (request.pollEnabled() != null) entity.setPollEnabled(request.pollEnabled());
            if (request.taskEnabled() != null) entity.setTaskEnabled(request.taskEnabled());
            if (request.financeEnabled() != null) entity.setFinanceEnabled(request.financeEnabled());
            if (request.fundEnabled() != null) entity.setFundEnabled(request.fundEnabled());
            entity.setUpdatedAt(clock.instant());
            userSettingsRepository.save(entity);
        }
        return toUserSettingsResponse(entity);
    }

    private UserNotificationSettingsEntity getOrCreateUserSettings(UUID userId) {
        return userSettingsRepository.findById(userId)
                .orElseGet(() -> userSettingsRepository.save(
                        UserNotificationSettingsEntity.createDefault(userId, clock.instant())
                ));
    }

    // =========================================================================
    // NOTI-06: Group Notification Settings (Mute 1h / 8h / 1d / until unmuted)
    // =========================================================================

    @Transactional(readOnly = true)
    public GroupNotificationSettingsResponse getGroupSettings(UUID groupId, UUID userId) {
        groupPermissionService.requireReadableMembership(groupId, userId);
        Instant now = clock.instant();
        return loadGroupSettingsResponse(groupId, userId, now);
    }

    @Transactional
    public GroupNotificationSettingsResponse updateGroupSettings(
            UUID groupId,
            UUID userId,
            UpdateGroupNotificationSettingsRequest request
    ) {
        groupPermissionService.requireReadableMembership(groupId, userId);
        Instant now = clock.instant();

        boolean muted;
        Instant mutedUntil = null;
        String normalizedDuration = request != null && request.duration() != null
                ? request.duration().trim().toUpperCase(Locale.ROOT)
                : null;

        if (request == null) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED, "Group notification setting payload is required.");
        }

        if (Boolean.FALSE.equals(request.muted())
                || "UNMUTE".equals(normalizedDuration)
                || "NONE".equals(normalizedDuration)
                || "OFF".equals(normalizedDuration)) {
            muted = false;
            mutedUntil = null;
        } else {
            muted = true;
            if (normalizedDuration != null && !normalizedDuration.isEmpty()) {
                mutedUntil = switch (normalizedDuration) {
                    case "1H", "ONE_HOUR", "1_HOUR" -> now.plus(Duration.ofHours(1));
                    case "8H", "EIGHT_HOURS", "8_HOURS" -> now.plus(Duration.ofHours(8));
                    case "1D", "ONE_DAY", "1_DAY", "24H" -> now.plus(Duration.ofDays(1));
                    case "UNTIL_UNMUTED", "FOREVER", "INDEFINITE" -> null;
                    default -> throw new BusinessException(
                            ErrorCode.VALIDATION_FAILED,
                            "Unsupported group mute duration: " + request.duration()
                    );
                };
            } else if (request.mutedUntil() != null) {
                if (!request.mutedUntil().isAfter(now)) {
                    throw new BusinessException(
                            ErrorCode.VALIDATION_FAILED,
                            "mutedUntil must be a future timestamp."
                    );
                }
                mutedUntil = request.mutedUntil();
            }
        }

        jdbc.update("""
                INSERT INTO group_notification_settings (id, group_id, user_id, muted, muted_until, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT (user_id, group_id)
                DO UPDATE SET muted = EXCLUDED.muted,
                              muted_until = EXCLUDED.muted_until,
                              updated_at = EXCLUDED.updated_at
                """,
                UUID.randomUUID(),
                groupId,
                userId,
                muted,
                mutedUntil == null ? null : Timestamp.from(mutedUntil),
                Timestamp.from(now),
                Timestamp.from(now)
        );

        return loadGroupSettingsResponse(groupId, userId, now);
    }

    private GroupNotificationSettingsResponse loadGroupSettingsResponse(UUID groupId, UUID userId, Instant now) {
        List<GroupMuteRow> rows = jdbc.query("""
                SELECT group_id, user_id, muted, muted_until, updated_at
                FROM group_notification_settings
                WHERE group_id = ? AND user_id = ?
                """,
                (rs, i) -> new GroupMuteRow(
                        rs.getObject("group_id", UUID.class),
                        rs.getObject("user_id", UUID.class),
                        rs.getBoolean("muted"),
                        toInstant(rs.getTimestamp("muted_until")),
                        toInstant(rs.getTimestamp("updated_at"))
                ),
                groupId,
                userId
        );
        if (rows.isEmpty()) {
            return new GroupNotificationSettingsResponse(groupId, false, false, "UNMUTED", null, now);
        }
        GroupMuteRow row = rows.get(0);
        boolean effectivelyMuted = row.muted() && (row.mutedUntil() == null || row.mutedUntil().isAfter(now));
        String muteOption;
        if (!row.muted()) {
            muteOption = "UNMUTED";
        } else if (!effectivelyMuted) {
            muteOption = "EXPIRED";
        } else if (row.mutedUntil() == null) {
            muteOption = "UNTIL_UNMUTED";
        } else {
            muteOption = "TIMED";
        }
        return new GroupNotificationSettingsResponse(
                groupId,
                effectivelyMuted,
                effectivelyMuted,
                muteOption,
                effectivelyMuted ? row.mutedUntil() : null,
                row.updatedAt()
        );
    }

    public boolean isGroupEffectivelyMuted(UUID groupId, UUID userId, Instant now) {
        if (groupId == null || userId == null) {
            return false;
        }
        List<GroupMuteRow> rows = jdbc.query("""
                SELECT group_id, user_id, muted, muted_until, updated_at
                FROM group_notification_settings
                WHERE group_id = ? AND user_id = ?
                """,
                (rs, i) -> new GroupMuteRow(
                        rs.getObject("group_id", UUID.class),
                        rs.getObject("user_id", UUID.class),
                        rs.getBoolean("muted"),
                        toInstant(rs.getTimestamp("muted_until")),
                        toInstant(rs.getTimestamp("updated_at"))
                ),
                groupId,
                userId
        );
        if (rows.isEmpty()) {
            return false;
        }
        GroupMuteRow row = rows.get(0);
        return row.muted() && (row.mutedUntil() == null || row.mutedUntil().isAfter(now));
    }

    // =========================================================================
    // Device Token Lifecycle (user_devices + V10 uq_user_devices_active_push_token)
    // =========================================================================

    @Transactional(readOnly = true)
    public List<UserDeviceResponse> listDevices(UUID userId) {
        return jdbc.query("""
                SELECT id, user_id, device_id, platform, push_token, active, last_seen_at, updated_at
                FROM user_devices
                WHERE user_id = ?
                ORDER BY last_seen_at DESC, id DESC
                """,
                this::mapDeviceRow,
                userId
        );
    }

    @Transactional
    public UserDeviceResponse registerDevice(UUID userId, RegisterDeviceRequest request) {
        if (request == null
                || request.deviceId() == null || request.deviceId().isBlank()
                || request.platform() == null || request.platform().isBlank()
                || request.pushToken() == null || request.pushToken().isBlank()) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED, "deviceId, platform, and pushToken are required.");
        }
        String deviceId = request.deviceId().trim();
        String platform = request.platform().trim().toUpperCase(Locale.ROOT);
        String pushToken = request.pushToken().trim();
        if (!VALID_PLATFORMS.contains(platform)) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED, "platform must be ANDROID, IOS, or WEB.");
        }

        Instant now = clock.instant();
        Timestamp ts = Timestamp.from(now);

        // Enforce V10 uq_user_devices_active_push_token: deactivate any other device/user currently holding this token.
        jdbc.update("""
                UPDATE user_devices
                SET active = FALSE, updated_at = ?
                WHERE push_token = ?
                  AND (user_id <> ? OR device_id <> ?)
                  AND active = TRUE
                """,
                ts,
                pushToken,
                userId,
                deviceId
        );

        UUID newId = UUID.randomUUID();
        jdbc.update("""
                INSERT INTO user_devices (id, user_id, platform, push_token, device_id, active, last_seen_at, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, TRUE, ?, ?, ?)
                ON CONFLICT (user_id, device_id)
                DO UPDATE SET platform = EXCLUDED.platform,
                              push_token = EXCLUDED.push_token,
                              active = TRUE,
                              last_seen_at = EXCLUDED.last_seen_at,
                              updated_at = EXCLUDED.updated_at
                """,
                newId,
                userId,
                platform,
                pushToken,
                deviceId,
                ts,
                ts,
                ts
        );

        return jdbc.query("""
                SELECT id, user_id, device_id, platform, push_token, active, last_seen_at, updated_at
                FROM user_devices
                WHERE user_id = ? AND device_id = ?
                """,
                this::mapDeviceRow,
                userId,
                deviceId
        ).get(0);
    }

    @Transactional
    public void deactivateDevice(UUID userId, String deviceId) {
        if (deviceId == null || deviceId.isBlank()) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED, "deviceId is required.");
        }
        Instant now = clock.instant();
        jdbc.update("""
                UPDATE user_devices
                SET active = FALSE, updated_at = ?
                WHERE user_id = ? AND device_id = ?
                """,
                Timestamp.from(now),
                userId,
                deviceId.trim()
        );
    }

    public void deactivatePushToken(String pushToken) {
        if (pushToken == null || pushToken.isBlank()) {
            return;
        }
        requiresNewTx.executeWithoutResult(status -> jdbc.update(
                "UPDATE user_devices SET active = FALSE, updated_at = ? WHERE push_token = ? AND active = TRUE",
                Timestamp.from(clock.instant()),
                pushToken
        ));
    }

    // =========================================================================
    // Domain Event Processing + Push Decision + Push Failure Isolation
    // =========================================================================

    public void processDomainEvent(NotificationDomainEvent event) {
        if (event == null || event.recipientUserIds() == null || event.recipientUserIds().isEmpty()) {
            return;
        }
        String category = normalizeCategory(event.category());
        String priority = normalizePriority(event.priority());
        Instant occurredAt = event.occurredAt() != null ? event.occurredAt() : clock.instant();

        for (UUID recipientId : event.recipientUserIds()) {
            if (recipientId == null) {
                continue;
            }
            if (event.actorId() != null && event.actorId().equals(recipientId)) {
                continue;
            }
            String recipientEventKey = (event.eventKey() == null || event.eventKey().isBlank()
                    ? UUID.randomUUID().toString()
                    : event.eventKey()) + ":" + recipientId;

            try {
                PersistedDispatchPlan plan = requiresNewTx.execute(status -> persistInboxAndBuildDispatchPlan(
                        recipientId,
                        recipientEventKey,
                        event,
                        category,
                        priority,
                        occurredAt
                ));
                if (plan != null && "ELIGIBLE".equals(plan.pushDecision()) && !plan.devices().isEmpty()) {
                    dispatchPushMessagesSafely(plan);
                }
            } catch (RuntimeException ignored) {
                // Push or notification failure must NEVER roll back or break the originating business transaction.
            }
        }
    }

    public void processChatMutationEvent(ChatRealtimeEvents.DomainMutationEvent chatEvent) {
        if (chatEvent == null || !"MESSAGE_CREATED".equals(chatEvent.type())
                || chatEvent.conversationId() == null || chatEvent.messageId() == null) {
            return;
        }
        try {
            List<ChatNotificationContext> contexts = requiresNewTx.execute(status ->
                    loadChatNotificationContexts(chatEvent.conversationId(), chatEvent.messageId(), chatEvent.actorId())
            );
            if (contexts == null || contexts.isEmpty()) {
                return;
            }
            for (ChatNotificationContext ctx : contexts) {
                Map<String, Object> metadata = new LinkedHashMap<>();
                metadata.put("conversationId", ctx.conversationId().toString());
                metadata.put("messageId", chatEvent.messageId().toString());
                if (ctx.groupId() != null) {
                    metadata.put("groupId", ctx.groupId().toString());
                }
                NotificationDomainEvent domainEvent = new NotificationDomainEvent(
                        "CHAT_MESSAGE_CREATED:" + chatEvent.messageId(),
                        "CHAT_MESSAGE_CREATED",
                        "CHAT",
                        "NORMAL",
                        false,
                        chatEvent.actorId(),
                        ctx.groupId(),
                        ctx.recipientIds(),
                        ctx.title(),
                        ctx.body(),
                        "CONVERSATION",
                        ctx.conversationId(),
                        "/chat/conversation",
                        metadata,
                        chatEvent.occurredAt() != null ? chatEvent.occurredAt() : clock.instant()
                );
                processDomainEvent(domainEvent);
            }
        } catch (RuntimeException ignored) {
            // Never fail chat transaction
        }
    }

    private PersistedDispatchPlan persistInboxAndBuildDispatchPlan(
            UUID recipientId,
            String recipientEventKey,
            NotificationDomainEvent event,
            String category,
            String priority,
            Instant now
    ) {
        jdbc.query(
                "SELECT pg_advisory_xact_lock(hashtextextended(?, 0))",
                (org.springframework.jdbc.core.ResultSetExtractor<Object>) rs -> null,
                recipientEventKey
        );
        Integer existingCount = jdbc.queryForObject(
                "SELECT count(*) FROM notifications WHERE user_id = ? AND data->>'eventKey' = ?",
                Integer.class,
                recipientId,
                recipientEventKey
        );
        if (existingCount != null && existingCount > 0) {
            return null;
        }

        UserNotificationSettingsEntity settings = getOrCreateUserSettings(recipientId);
        UUID conversationId = extractUuidFromMetadata(event.metadata(), "conversationId");
        if (conversationId == null && "CONVERSATION".equalsIgnoreCase(event.targetType())) {
            conversationId = event.targetId();
        }

        String pushDecision;
        List<UserDeviceResponse> activeDevices = Collections.emptyList();

        if ("CHAT".equals(category)
                && conversationId != null
                && chatRealtimeCoordinator.isUserSubscribedToConversation(recipientId, conversationId)) {
            pushDecision = "SUPPRESSED_OPEN_CONVERSATION";
        } else if (!settings.isPushEnabled()) {
            pushDecision = "SUPPRESSED_USER_PUSH_DISABLED";
        } else if (!isCategoryEnabled(settings, category)) {
            pushDecision = "SUPPRESSED_CATEGORY_DISABLED";
        } else if (event.groupId() != null
                && isGroupEffectivelyMuted(event.groupId(), recipientId, now)
                && !event.critical()) {
            pushDecision = "SUPPRESSED_GROUP_MUTED";
        } else {
            activeDevices = jdbc.query("""
                    SELECT id, user_id, device_id, platform, push_token, active, last_seen_at, updated_at
                    FROM user_devices
                    WHERE user_id = ? AND active = TRUE
                    ORDER BY last_seen_at DESC, id DESC
                    """,
                    this::mapDeviceRow,
                    recipientId
            );
            pushDecision = activeDevices.isEmpty() ? "NO_ACTIVE_DEVICES" : "ELIGIBLE";
        }

        UUID notificationId = UUID.randomUUID();
        Map<String, Object> dataPayload = new LinkedHashMap<>();
        if (event.metadata() != null) {
            dataPayload.putAll(event.metadata());
        }
        dataPayload.put("eventKey", recipientEventKey);
        dataPayload.put("eventType", event.eventType());
        dataPayload.put("critical", event.critical());
        if (event.targetType() != null) dataPayload.put("targetType", event.targetType());
        if (event.targetId() != null) dataPayload.put("targetId", event.targetId().toString());
        if (event.route() != null) dataPayload.put("route", event.route());
        if (event.groupId() != null) dataPayload.put("groupId", event.groupId().toString());
        dataPayload.put("pushDecision", pushDecision);

        String collapseKey = null;
        if ("CHAT".equals(category) && conversationId != null) {
            collapseKey = "chat:" + conversationId;
            dataPayload.put("collapseKey", collapseKey);
        }

        String jsonData;
        try {
            jsonData = objectMapper.writeValueAsString(dataPayload);
        } catch (Exception ex) {
            jsonData = "{}";
        }

        jdbc.update("""
                INSERT INTO notifications (
                    id, user_id, actor_id, group_id, category, priority,
                    title, body, data, read_at, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?::jsonb, NULL, ?)
                """,
                notificationId,
                recipientId,
                event.actorId(),
                event.groupId(),
                category,
                priority,
                event.title(),
                event.body(),
                jsonData,
                Timestamp.from(now)
        );

        return new PersistedDispatchPlan(
                notificationId,
                recipientId,
                category,
                priority,
                event.critical(),
                event.title(),
                event.body(),
                collapseKey,
                pushDecision,
                dataPayload,
                activeDevices
        );
    }

    private void dispatchPushMessagesSafely(PersistedDispatchPlan plan) {
        boolean anyGatewayAccepted = false;
        boolean anyProviderFailure = false;
        boolean externalConfigBlocked = false;
        Map<String, String> stringData = new LinkedHashMap<>();
        stringData.put("notificationId", plan.notificationId().toString());
        stringData.put("category", plan.category());
        stringData.put("critical", Boolean.toString(plan.critical()));
        stringData.put("action", "OPEN_NOTIFICATION");
        for (String key : List.of(
                "eventType", "targetType", "targetId", "groupId", "conversationId", "activityId", "route"
        )) {
            Object value = plan.dataPayload().get(key);
            if (value != null) {
                stringData.put(key, String.valueOf(value));
            }
        }
        String deepLink = plan.dataPayload().get("route") == null
                ? null
                : String.valueOf(plan.dataPayload().get("route"));
        if (deepLink != null) {
            stringData.put("deepLink", deepLink);
        }

        for (UserDeviceResponse device : plan.devices()) {
            try {
                PushMessage message = new PushMessage(
                        plan.notificationId(),
                        plan.recipientId(),
                        device.deviceId(),
                        device.platform(),
                        device.pushToken(),
                        plan.category(),
                        plan.priority(),
                        plan.critical(),
                        plan.title(),
                        plan.body(),
                        plan.collapseKey(),
                        stringData
                );
                PushDeliveryResult result = pushGateway.sendPush(message);
                if (result != null && result.status() == PushDeliveryStatus.INVALID_TOKEN) {
                    deactivatePushToken(device.pushToken());
                } else if (result != null && result.status() == PushDeliveryStatus.GATEWAY_ACCEPTED) {
                    anyGatewayAccepted = true;
                } else if (result != null && result.status() == PushDeliveryStatus.EXTERNAL_CONFIG_BLOCKED) {
                    externalConfigBlocked = true;
                } else {
                    anyProviderFailure = true;
                }
            } catch (RuntimeException ex) {
                anyProviderFailure = true;
            }
        }

        String finalDecision = anyGatewayAccepted ? "GATEWAY_ACCEPTED"
                : (externalConfigBlocked ? "EXTERNAL_CONFIG_BLOCKED"
                : (anyProviderFailure ? "PROVIDER_FAILED" : "NO_ACTIVE_DEVICES"));
        try {
            requiresNewTx.executeWithoutResult(status -> jdbc.update("""
                    UPDATE notifications
                    SET data = jsonb_set(COALESCE(data, '{}'::jsonb), '{pushDecision}', to_jsonb(?::text), true)
                    WHERE id = ?
                    """,
                    finalDecision,
                    plan.notificationId()
            ));
        } catch (RuntimeException ignored) {
            // Preserve persisted inbox row even if metadata update fails
        }
    }

    // =========================================================================
    // Deep Link & Stale Target Resolution (Section 19)
    // =========================================================================

    private NotificationItemResponse toNotificationItemResponse(NotificationRow row, UUID viewerUserId) {
        Map<String, Object> dataMap = parseJsonData(row.dataJson());
        boolean critical = Boolean.TRUE.equals(dataMap.get("critical"));
        NotificationActorSummary actor = row.actorId() == null ? null : new NotificationActorSummary(
                row.actorId(),
                row.actorDisplayName() != null && !row.actorDisplayName().isBlank()
                        ? row.actorDisplayName()
                        : (row.actorUsername() != null ? row.actorUsername() : "Thành viên"),
                row.actorAvatar()
        );
        NotificationGroupSummary group = row.groupId() == null ? null : new NotificationGroupSummary(
                row.groupId(),
                row.groupName() != null ? row.groupName() : "Nhóm",
                row.groupStatus() != null ? row.groupStatus() : "DELETED"
        );

        NotificationTargetInfo target = resolveTargetActionability(row, dataMap, viewerUserId);

        return new NotificationItemResponse(
                row.id(),
                row.category(),
                row.priority(),
                critical,
                row.title(),
                row.body(),
                actor,
                group,
                target,
                row.readAt() != null,
                row.readAt(),
                row.createdAt()
        );
    }

    private NotificationTargetInfo resolveTargetActionability(
            NotificationRow row,
            Map<String, Object> dataMap,
            UUID viewerUserId
    ) {
        String targetType = dataMap.get("targetType") != null
                ? String.valueOf(dataMap.get("targetType"))
                : row.category();
        UUID targetId = extractUuidFromMetadata(dataMap, "targetId");
        String route = dataMap.get("route") != null ? String.valueOf(dataMap.get("route")) : defaultRouteForCategory(row.category());

        Map<String, Object> params = new LinkedHashMap<>(dataMap);
        params.remove("eventKey");
        params.remove("pushDecision");
        params.remove("collapseKey");
        params.remove("critical");
        params.remove("eventType");
        params.remove("route");
        params.remove("targetType");
        params.remove("targetId");
        if (row.groupId() != null) {
            params.putIfAbsent("groupId", row.groupId().toString());
        }
        if (targetId != null) {
            params.putIfAbsent("targetId", targetId.toString());
        }

        if (!Set.of("GROUP", "GROUP_INVITATION", "CONVERSATION", "ACTIVITY", "POLL", "TASK", "EXPENSE", "SETTLEMENT", "FUND")
                .contains(targetType.toUpperCase(Locale.ROOT))) {
            return new NotificationTargetInfo(
                    targetType, targetId, route, false,
                    "LiÃªn káº¿t thÃ´ng bÃ¡o nÃ y chÆ°a Ä‘Æ°á»£c há»— trá»£.", params
            );
        }

        if ("CONVERSATION".equalsIgnoreCase(targetType) && targetId != null) {
            Integer canOpenConversation = jdbc.queryForObject("""
                    SELECT count(*)
                    FROM conversations c
                    LEFT JOIN group_conversations gc ON gc.conversation_id = c.id
                    LEFT JOIN direct_conversations dc ON dc.conversation_id = c.id
                    WHERE c.id = ?
                      AND (
                        (c.type = 'GROUP' AND gc.group_id = ? AND EXISTS (
                            SELECT 1 FROM group_memberships gm
                            WHERE gm.group_id = gc.group_id AND gm.user_id = ? AND gm.status = 'ACTIVE'
                        ))
                        OR
                        (c.type = 'DIRECT' AND (dc.user_id_1 = ? OR dc.user_id_2 = ?))
                      )
                    """,
                    Integer.class,
                    targetId,
                    row.groupId(),
                    viewerUserId,
                    viewerUserId,
                    viewerUserId
            );
            if (canOpenConversation == null || canOpenConversation == 0) {
                return new NotificationTargetInfo(
                        targetType, targetId, route, false,
                        "Cuá»™c trÃ² chuyá»‡n nÃ y khÃ´ng cÃ²n kháº£ dá»¥ng.", params
                );
            }
        }

        // 1. Check group access if notification belongs to a group (except pending group invitation)
        if (row.groupId() != null && !"GROUP_INVITATION".equalsIgnoreCase(targetType)) {
            if (row.groupStatus() == null || "DELETED".equalsIgnoreCase(row.groupStatus())) {
                return new NotificationTargetInfo(
                        targetType, targetId, route, false,
                        "Nhóm này đã bị xóa hoặc không còn tồn tại.", params
                );
            }
            Integer activeMembership = jdbc.queryForObject("""
                    SELECT count(*) FROM group_memberships
                    WHERE group_id = ? AND user_id = ? AND status = 'ACTIVE'
                    """,
                    Integer.class,
                    row.groupId(),
                    viewerUserId
            );
            if (activeMembership == null || activeMembership == 0) {
                return new NotificationTargetInfo(
                        targetType, targetId, route, false,
                        "Bạn không còn là thành viên hoạt động của nhóm này.", params
                );
            }
        }

        // 2. Check target-specific existence & actionability
        if ("GROUP_INVITATION".equalsIgnoreCase(targetType) && targetId != null) {
            if (row.groupStatus() == null || "DELETED".equalsIgnoreCase(row.groupStatus())) {
                return new NotificationTargetInfo(
                        targetType, targetId, route, false,
                        "NhÃ³m cá»§a lá»i má»i khÃ´ng cÃ²n kháº£ dá»¥ng.", params
                );
            }
            List<String> statuses = jdbc.query(
                    "SELECT status FROM group_invitations WHERE id = ? AND invitee_id = ?",
                    (rs, i) -> rs.getString("status"),
                    targetId,
                    viewerUserId
            );
            if (statuses.isEmpty() || !"PENDING".equalsIgnoreCase(statuses.get(0))) {
                return new NotificationTargetInfo(
                        targetType, targetId, route, false,
                        "Lời mời vào nhóm này đã được xử lý hoặc hết hiệu lực.", params
                );
            }
        } else if ("ACTIVITY".equalsIgnoreCase(targetType) && targetId != null) {
            List<String> statuses = jdbc.query(
                    "SELECT status FROM activities WHERE id = ?",
                    (rs, i) -> rs.getString("status"),
                    targetId
            );
            if (statuses.isEmpty() || "CANCELLED".equalsIgnoreCase(statuses.get(0))) {
                return new NotificationTargetInfo(
                        targetType, targetId, route, false,
                        "Hoạt động này đã bị hủy hoặc không còn tồn tại.", params
                );
            }
        } else if ("POLL".equalsIgnoreCase(targetType) && targetId != null) {
            List<UUID> activityIds = jdbc.query("""
                    SELECT p.activity_id FROM polls p
                    JOIN activities a ON a.id = p.activity_id
                    WHERE p.id = ? AND a.group_id = ?
                    """, (rs, i) -> rs.getObject("activity_id", UUID.class), targetId, row.groupId());
            if (activityIds.isEmpty()) {
                return new NotificationTargetInfo(
                        targetType, targetId, route, false,
                        "Bình chọn này không còn tồn tại.", params
                );
            }
            params.put("activityId", activityIds.get(0).toString());
            route = "/activities/detail";
        } else if ("TASK".equalsIgnoreCase(targetType) && targetId != null) {
            List<UUID> activityIds = jdbc.query("""
                    SELECT t.activity_id FROM tasks t
                    JOIN activities a ON a.id = t.activity_id
                    WHERE t.id = ? AND a.group_id = ?
                    """, (rs, i) -> rs.getObject("activity_id", UUID.class), targetId, row.groupId());
            if (activityIds.isEmpty()) {
                return new NotificationTargetInfo(
                        targetType, targetId, route, false,
                        "Công việc này không còn tồn tại.", params
                );
            }
            params.put("activityId", activityIds.get(0).toString());
            route = "/activities/detail";
        } else if ("EXPENSE".equalsIgnoreCase(targetType) && targetId != null) {
            List<String> statuses = jdbc.query(
                    "SELECT status FROM expenses WHERE id = ?",
                    (rs, i) -> rs.getString("status"),
                    targetId
            );
            if (statuses.isEmpty() || "CANCELLED".equalsIgnoreCase(statuses.get(0))) {
                return new NotificationTargetInfo(
                        targetType, targetId, route, false,
                        "Khoản chi này đã bị hủy hoặc không còn tồn tại.", params
                );
            }
        } else if ("SETTLEMENT".equalsIgnoreCase(targetType) && targetId != null) {
            List<String> statuses = jdbc.query(
                    "SELECT status FROM settlements WHERE id = ?",
                    (rs, i) -> rs.getString("status"),
                    targetId
            );
            if (statuses.isEmpty() || "CANCELLED".equalsIgnoreCase(statuses.get(0))) {
                return new NotificationTargetInfo(
                        targetType, targetId, route, false,
                        "Yêu cầu thanh toán này đã bị hủy hoặc không còn tồn tại.", params
                );
            }
        } else if ("FUND".equalsIgnoreCase(targetType) && targetId != null) {
            Integer count = jdbc.queryForObject("SELECT count(*) FROM group_funds WHERE id = ?", Integer.class, targetId);
            if (count == null || count == 0) {
                return new NotificationTargetInfo(
                        targetType, targetId, route, false,
                        "Quỹ nhóm này không còn tồn tại.", params
                );
            }
        }

        return new NotificationTargetInfo(targetType, targetId, route, true, null, params);
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    private List<ChatNotificationContext> loadChatNotificationContexts(
            UUID conversationId,
            UUID messageId,
            UUID actorId
    ) {
        List<Map<String, Object>> rows = jdbc.queryForList("""
                SELECT c.type AS conv_type,
                       gc.group_id AS group_id,
                       g.name AS group_name,
                       dc.user_id_1 AS user_a_id,
                       dc.user_id_2 AS user_b_id,
                       m.content AS msg_content,
                       u.display_name AS sender_name,
                       u.username AS sender_username
                FROM conversations c
                JOIN messages m ON m.id = ? AND m.conversation_id = c.id
                LEFT JOIN group_conversations gc ON gc.conversation_id = c.id
                LEFT JOIN groups g ON g.id = gc.group_id
                LEFT JOIN direct_conversations dc ON dc.conversation_id = c.id
                LEFT JOIN users u ON u.id = ?
                WHERE c.id = ?
                """,
                messageId,
                actorId,
                conversationId
        );
        if (rows.isEmpty()) {
            return Collections.emptyList();
        }
        Map<String, Object> row = rows.get(0);
        String convType = (String) row.get("conv_type");
        UUID groupId = (UUID) row.get("group_id");
        String groupName = (String) row.get("group_name");
        String senderName = row.get("sender_name") != null
                ? String.valueOf(row.get("sender_name"))
                : (row.get("sender_username") != null ? String.valueOf(row.get("sender_username")) : "Thành viên");
        String content = row.get("msg_content") != null ? String.valueOf(row.get("msg_content")) : "Tin nhắn mới";
        if (content.length() > 120) {
            content = content.substring(0, 117) + "...";
        }

        List<UUID> recipients = new ArrayList<>();
        String title;
        String body;
        if ("GROUP".equalsIgnoreCase(convType) && groupId != null) {
            recipients = jdbc.query(
                    "SELECT user_id FROM group_memberships WHERE group_id = ? AND status = 'ACTIVE' AND user_id <> ?",
                    (rs, i) -> rs.getObject("user_id", UUID.class),
                    groupId,
                    actorId
            );
            title = groupName != null ? ("Tin nhắn mới trong " + groupName) : "Tin nhắn nhóm mới";
            body = senderName + ": " + content;
        } else {
            UUID userA = (UUID) row.get("user_a_id");
            UUID userB = (UUID) row.get("user_b_id");
            if (userA != null && !userA.equals(actorId)) recipients.add(userA);
            if (userB != null && !userB.equals(actorId)) recipients.add(userB);
            title = "Tin nhắn từ " + senderName;
            body = content;
        }
        if (recipients.isEmpty()) {
            return Collections.emptyList();
        }
        return List.of(new ChatNotificationContext(conversationId, groupId, recipients, title, body));
    }

    private boolean isCategoryEnabled(UserNotificationSettingsEntity settings, String category) {
        return switch (category) {
            case "SOCIAL" -> settings.isSocialEnabled();
            case "GROUP" -> settings.isGroupEnabled();
            case "CHAT" -> settings.isChatEnabled();
            case "ACTIVITY" -> settings.isActivityEnabled();
            case "POLL" -> settings.isPollEnabled();
            case "TASK" -> settings.isTaskEnabled();
            case "FINANCE" -> settings.isFinanceEnabled();
            case "FUND" -> settings.isFundEnabled();
            default -> true;
        };
    }

    private String normalizeCategory(String category) {
        if (category == null) return "GROUP";
        String upper = category.trim().toUpperCase(Locale.ROOT);
        return VALID_CATEGORIES.contains(upper) ? upper : "GROUP";
    }

    private String normalizePriority(String priority) {
        if (priority == null) return "NORMAL";
        String upper = priority.trim().toUpperCase(Locale.ROOT);
        return VALID_PRIORITIES.contains(upper) ? upper : "NORMAL";
    }

    private String defaultRouteForCategory(String category) {
        return switch (category) {
            case "SOCIAL" -> "/social/requests";
            case "GROUP" -> "/groups/detail";
            case "CHAT" -> "/chat";
            case "ACTIVITY" -> "/activities/detail";
            case "POLL" -> "/activities/polls/detail";
            case "TASK" -> "/activities/tasks/detail";
            case "FINANCE" -> "/groups/settlements";
            case "FUND" -> "/groups/fund";
            default -> "/notifications";
        };
    }

    private UUID extractUuidFromMetadata(Map<String, Object> map, String key) {
        if (map == null || !map.containsKey(key) || map.get(key) == null) {
            return null;
        }
        try {
            return UUID.fromString(String.valueOf(map.get(key)));
        } catch (IllegalArgumentException ex) {
            return null;
        }
    }

    private Map<String, Object> parseJsonData(String json) {
        if (json == null || json.isBlank()) {
            return new LinkedHashMap<>();
        }
        try {
            return objectMapper.readValue(json, new TypeReference<LinkedHashMap<String, Object>>() {});
        } catch (Exception ex) {
            return new LinkedHashMap<>();
        }
    }

    private long queryTotalCount(UUID userId) {
        Long count = jdbc.queryForObject(
                "SELECT count(*) FROM notifications WHERE user_id = ?",
                Long.class,
                userId
        );
        return count == null ? 0L : count;
    }

    private UserNotificationSettingsResponse toUserSettingsResponse(UserNotificationSettingsEntity entity) {
        return new UserNotificationSettingsResponse(
                entity.isPushEnabled(),
                entity.isSocialEnabled(),
                entity.isGroupEnabled(),
                entity.isChatEnabled(),
                entity.isActivityEnabled(),
                entity.isPollEnabled(),
                entity.isTaskEnabled(),
                entity.isFinanceEnabled(),
                entity.isFundEnabled(),
                entity.getUpdatedAt()
        );
    }

    private NotificationRow mapNotificationRow(ResultSet rs, int rowNum) throws SQLException {
        return new NotificationRow(
                rs.getObject("id", UUID.class),
                rs.getObject("user_id", UUID.class),
                rs.getObject("actor_id", UUID.class),
                rs.getObject("group_id", UUID.class),
                rs.getString("category"),
                rs.getString("priority"),
                rs.getString("title"),
                rs.getString("body"),
                rs.getString("data"),
                toInstant(rs.getTimestamp("read_at")),
                toInstant(rs.getTimestamp("created_at")),
                rs.getString("actor_display_name"),
                rs.getString("actor_username"),
                rs.getString("actor_avatar"),
                rs.getString("group_name"),
                rs.getString("group_status")
        );
    }

    private UserDeviceResponse mapDeviceRow(ResultSet rs, int rowNum) throws SQLException {
        return new UserDeviceResponse(
                rs.getObject("id", UUID.class),
                rs.getObject("user_id", UUID.class),
                rs.getString("device_id"),
                rs.getString("platform"),
                rs.getString("push_token"),
                rs.getBoolean("active"),
                toInstant(rs.getTimestamp("last_seen_at")),
                toInstant(rs.getTimestamp("updated_at"))
        );
    }

    private static Instant toInstant(Timestamp ts) {
        return ts == null ? null : ts.toInstant();
    }

    private record NotificationRow(
            UUID id,
            UUID userId,
            UUID actorId,
            UUID groupId,
            String category,
            String priority,
            String title,
            String body,
            String dataJson,
            Instant readAt,
            Instant createdAt,
            String actorDisplayName,
            String actorUsername,
            String actorAvatar,
            String groupName,
            String groupStatus
    ) {
        NotificationRow withReadAt(Instant newReadAt) {
            return new NotificationRow(
                    id, userId, actorId, groupId, category, priority, title, body,
                    dataJson, newReadAt, createdAt, actorDisplayName, actorUsername,
                    actorAvatar, groupName, groupStatus
            );
        }
    }

    private record GroupMuteRow(
            UUID groupId,
            UUID userId,
            boolean muted,
            Instant mutedUntil,
            Instant updatedAt
    ) {
    }

    private record PersistedDispatchPlan(
            UUID notificationId,
            UUID recipientId,
            String category,
            String priority,
            boolean critical,
            String title,
            String body,
            String collapseKey,
            String pushDecision,
            Map<String, Object> dataPayload,
            List<UserDeviceResponse> devices
    ) {
    }

    private record ChatNotificationContext(
            UUID conversationId,
            UUID groupId,
            List<UUID> recipientIds,
            String title,
            String body
    ) {
    }
}
