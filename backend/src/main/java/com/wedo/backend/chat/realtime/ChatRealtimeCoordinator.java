package com.wedo.backend.chat.realtime;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.wedo.backend.chat.dto.ChatResponses;
import com.wedo.backend.chat.realtime.ChatRealtimeEvents.ClientCommand;
import com.wedo.backend.chat.realtime.ChatRealtimeEvents.DomainMutationEvent;
import com.wedo.backend.chat.realtime.ChatRealtimeEvents.DomainReadEvent;
import com.wedo.backend.chat.realtime.ChatRealtimeEvents.RedisFanoutEnvelope;
import com.wedo.backend.chat.realtime.ChatRealtimeEvents.ServerEvent;
import com.wedo.backend.chat.service.ChatService;
import com.wedo.backend.common.error.BusinessException;
import java.io.IOException;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;

@Component
public class ChatRealtimeCoordinator {
    public static final String REDIS_FANOUT_CHANNEL = "wedo:chat:realtime";
    private static final Duration TYPING_TTL = Duration.ofSeconds(5);
    private static final Duration PRESENCE_TTL = Duration.ofSeconds(120);

    private final String instanceId = UUID.randomUUID().toString();
    private final ChatService chatService;
    private final ObjectMapper objectMapper;
    private final StringRedisTemplate redisTemplate;

    private final Map<String, SessionState> sessionsById = new ConcurrentHashMap<>();
    private final Map<UUID, Set<String>> sessionIdsByUser = new ConcurrentHashMap<>();
    private final Map<TypingKey, Instant> activeTypings = new ConcurrentHashMap<>();
    private final Set<UUID> processedEventIds = Collections.newSetFromMap(new ConcurrentHashMap<>());

    @Autowired
    public ChatRealtimeCoordinator(
            ChatService chatService,
            ObjectMapper objectMapper,
            @Autowired(required = false) StringRedisTemplate redisTemplate
    ) {
        this.chatService = chatService;
        this.objectMapper = objectMapper;
        this.redisTemplate = redisTemplate;
    }

    public void registerSession(WebSocketSession session, UUID userId) {
        boolean wasOnline = isUserOnline(userId);
        SessionState state = new SessionState(session, userId);
        sessionsById.put(session.getId(), state);
        sessionIdsByUser.computeIfAbsent(userId, k -> ConcurrentHashMap.newKeySet()).add(session.getId());
        recordRedisSessionConnect(userId, session.getId());

        ChatResponses.User actor = safeUserSummary(userId);
        sendToSession(session, new ServerEvent(
                UUID.randomUUID(), "CONNECTED", null, null, null, null, null,
                actor, null, null, null, true, null, null, null, Instant.now()));

        if (!wasOnline && isUserOnline(userId)) {
            publishPresenceChange(userId, true);
        }
    }

    public void unregisterSession(WebSocketSession session) {
        SessionState removed = sessionsById.remove(session.getId());
        if (removed == null) return;
        UUID userId = removed.userId();
        Set<String> userSessions = sessionIdsByUser.get(userId);
        if (userSessions != null) {
            userSessions.remove(session.getId());
            if (userSessions.isEmpty()) {
                sessionIdsByUser.remove(userId, Collections.emptySet());
            }
        }
        recordRedisSessionDisconnect(userId, session.getId());

        if (!isUserOnline(userId)) {
            clearAllTypingForUser(userId);
            try {
                chatService.recordLastSeenSnapshot(userId, Instant.now());
            } catch (RuntimeException ignored) { }
            publishPresenceChange(userId, false);
        }
    }

    public void handleClientCommand(WebSocketSession session, String payload) {
        SessionState state = sessionsById.get(session.getId());
        if (state == null) return;
        UUID userId = state.userId();
        refreshRedisSessionPresence(userId, session.getId());

        final ClientCommand cmd;
        try {
            cmd = objectMapper.readValue(payload, ClientCommand.class);
        } catch (Exception ex) {
            sendError(session, null, "VALIDATION_FAILED", "Invalid realtime command payload.");
            return;
        }
        if (cmd == null || cmd.type() == null || cmd.type().isBlank()) {
            sendError(session, null, "VALIDATION_FAILED", "Command type is required.");
            return;
        }

        String type = cmd.type().trim().toUpperCase();
        try {
            switch (type) {
                case "PING" -> sendToSession(session, new ServerEvent(
                        UUID.randomUUID(), "PONG", null, null, null, null, null,
                        null, null, null, null, true, null, null, null, Instant.now()));
                case "SUBSCRIBE" -> handleSubscribe(session, state, cmd.conversationId());
                case "UNSUBSCRIBE" -> handleUnsubscribe(session, state, cmd.conversationId());
                case "TYPING_START" -> handleTyping(session, userId, cmd.conversationId(), true);
                case "TYPING_STOP" -> handleTyping(session, userId, cmd.conversationId(), false);
                case "MARK_READ" -> {
                    if (cmd.conversationId() == null || cmd.lastReadSequence() == null) {
                        sendError(session, cmd.conversationId(), "VALIDATION_FAILED", "conversationId and lastReadSequence are required.");
                        return;
                    }
                    chatService.read(cmd.conversationId(), userId, cmd.lastReadSequence());
                }
                default -> sendError(session, cmd.conversationId(), "VALIDATION_FAILED", "Unsupported command: " + type);
            }
        } catch (BusinessException ex) {
            sendError(session, cmd.conversationId(), ex.errorCode().name(), ex.getMessage());
        } catch (RuntimeException ex) {
            sendError(session, cmd.conversationId(), "ACCESS_DENIED", "Action denied.");
        }
    }

    private void handleSubscribe(WebSocketSession session, SessionState state, UUID conversationId) {
        if (conversationId == null || !chatService.canSubscribeConversation(conversationId, state.userId())) {
            sendError(session, conversationId, "ACCESS_DENIED", "Not authorized to subscribe to conversation.");
            return;
        }
        state.subscribedConversations().add(conversationId);
        List<UUID> visibleOnlineUsers = visibleOnlineParticipants(conversationId, state.userId());
        sendToSession(session, new ServerEvent(
                UUID.randomUUID(), "SUBSCRIBED", null, conversationId, null, null, null,
                null, null, null, null, null, visibleOnlineUsers, null, null, Instant.now()));
    }

    private void handleUnsubscribe(WebSocketSession session, SessionState state, UUID conversationId) {
        if (conversationId != null) {
            state.subscribedConversations().remove(conversationId);
        }
        sendToSession(session, new ServerEvent(
                UUID.randomUUID(), "UNSUBSCRIBED", null, conversationId, null, null, null,
                null, null, null, null, null, null, null, null, Instant.now()));
    }

    private void handleTyping(WebSocketSession session, UUID userId, UUID conversationId, boolean typing) {
        if (conversationId == null || !chatService.canSendInConversation(conversationId, userId)) {
            sendError(session, conversationId, "ACCESS_DENIED", "Not authorized to send typing indicator.");
            return;
        }
        TypingKey key = new TypingKey(conversationId, userId);
        if (typing) {
            activeTypings.put(key, Instant.now().plus(TYPING_TTL));
            writeRedisTypingKey(conversationId, userId, true);
        } else {
            activeTypings.remove(key);
            writeRedisTypingKey(conversationId, userId, false);
        }
        RedisFanoutEnvelope envelope = new RedisFanoutEnvelope(
                UUID.randomUUID(), instanceId, "TYPING_UPDATED", conversationId,
                null, null, null, userId, null, typing, null, Instant.now());
        publishAndDeliver(envelope);
    }

    @Scheduled(fixedDelay = 1000)
    public void expireStaleTypings() {
        Instant now = Instant.now();
        for (Map.Entry<TypingKey, Instant> entry : new ArrayList<>(activeTypings.entrySet())) {
            if (!now.isBefore(entry.getValue())) {
                if (activeTypings.remove(entry.getKey(), entry.getValue())) {
                    writeRedisTypingKey(entry.getKey().conversationId(), entry.getKey().userId(), false);
                    RedisFanoutEnvelope envelope = new RedisFanoutEnvelope(
                            UUID.randomUUID(), instanceId, "TYPING_UPDATED",
                            entry.getKey().conversationId(), null, null, null,
                            entry.getKey().userId(), null, false, null, now);
                    publishAndDeliver(envelope);
                }
            }
        }
    }

    public void onAfterCommitMutation(DomainMutationEvent event) {
        if ("MESSAGE_CREATED".equals(event.type()) && event.conversationId() != null && event.actorId() != null) {
            TypingKey key = new TypingKey(event.conversationId(), event.actorId());
            if (activeTypings.remove(key) != null) {
                writeRedisTypingKey(event.conversationId(), event.actorId(), false);
            }
        }
        RedisFanoutEnvelope envelope = new RedisFanoutEnvelope(
                event.eventId(), instanceId, event.type(), event.conversationId(),
                event.messageId(), event.sequence(), event.clientMessageId(),
                event.actorId(), null, null, null, event.occurredAt());
        publishAndDeliver(envelope);
    }

    public void onAfterCommitRead(DomainReadEvent event) {
        RedisFanoutEnvelope envelope = new RedisFanoutEnvelope(
                event.eventId(), instanceId, "READ_STATE_UPDATED", event.conversationId(),
                null, event.reader().lastReadSequence(), null,
                event.reader().userId(), event.reader(), null, null, event.occurredAt());
        publishAndDeliver(envelope);
    }

    public void onRedisMessage(String rawJson) {
        try {
            RedisFanoutEnvelope envelope = objectMapper.readValue(rawJson, RedisFanoutEnvelope.class);
            if (envelope != null) {
                deliverFanoutEnvelope(envelope);
            }
        } catch (Exception ignored) { }
    }

    public void publishAndDeliver(RedisFanoutEnvelope envelope) {
        deliverFanoutEnvelope(envelope);
        if (redisTemplate != null) {
            try {
                String json = objectMapper.writeValueAsString(envelope);
                redisTemplate.convertAndSend(REDIS_FANOUT_CHANNEL, json);
            } catch (Exception ignored) { }
        }
    }

    private void deliverFanoutEnvelope(RedisFanoutEnvelope envelope) {
        if (envelope.eventId() != null && !processedEventIds.add(envelope.eventId())) {
            return;
        }
        if (processedEventIds.size() > 5000) {
            processedEventIds.clear();
            if (envelope.eventId() != null) processedEventIds.add(envelope.eventId());
        }

        if ("PRESENCE_UPDATED".equals(envelope.type())) {
            deliverPresenceEnvelope(envelope);
            return;
        }

        UUID conversationId = envelope.conversationId();
        if (conversationId == null) return;

        Set<UUID> eligibleUsers = chatService.eligibleRecipientUserIds(conversationId);
        if (eligibleUsers.isEmpty()) return;

        ChatResponses.User actor = envelope.actorId() != null ? safeUserSummary(envelope.actorId()) : null;
        String alias = switch (envelope.type()) {
            case "MESSAGE_REACTION_UPDATED" -> "REACTION_UPDATED";
            case "READ_STATE_UPDATED" -> "MESSAGE_READ";
            case "TYPING_UPDATED" -> Boolean.TRUE.equals(envelope.typing()) ? "USER_TYPING" : "USER_STOPPED_TYPING";
            default -> null;
        };

        for (UUID recipientUserId : eligibleUsers) {
            Set<String> userSessionIds = sessionIdsByUser.get(recipientUserId);
            if (userSessionIds == null || userSessionIds.isEmpty()) continue;
            if (!chatService.canSubscribeConversation(conversationId, recipientUserId)) continue;

            ChatResponses.Message viewerMessage = null;
            if (envelope.messageId() != null) {
                Optional<ChatResponses.Message> projected = chatService.messageForViewer(envelope.messageId(), recipientUserId);
                if (projected.isEmpty()) continue;
                viewerMessage = projected.get();
            }

            ServerEvent eventForViewer = new ServerEvent(
                    envelope.eventId(),
                    envelope.type(),
                    alias,
                    conversationId,
                    envelope.messageId(),
                    envelope.sequence(),
                    envelope.clientMessageId(),
                    actor,
                    viewerMessage,
                    envelope.reader(),
                    envelope.typing(),
                    envelope.online(),
                    null,
                    null,
                    null,
                    envelope.occurredAt()
            );

            for (String sessionId : userSessionIds) {
                SessionState sessionState = sessionsById.get(sessionId);
                if (sessionState == null) continue;
                if ("TYPING_UPDATED".equals(envelope.type()) && !sessionState.subscribedConversations().contains(conversationId)) {
                    continue;
                }
                sendToSession(sessionState.session(), eventForViewer);
            }
        }
    }

    private void publishPresenceChange(UUID userId, boolean online) {
        RedisFanoutEnvelope envelope = new RedisFanoutEnvelope(
                UUID.randomUUID(), instanceId, "PRESENCE_UPDATED", null,
                null, null, null, userId, null, null, online, Instant.now());
        publishAndDeliver(envelope);
    }

    private void deliverPresenceEnvelope(RedisFanoutEnvelope envelope) {
        UUID actorId = envelope.actorId();
        if (actorId == null) return;
        ChatResponses.User actor = safeUserSummary(actorId);
        Set<UUID> peers = chatService.sharedPeerUserIds(actorId);
        for (UUID peerId : peers) {
            Set<String> peerSessions = sessionIdsByUser.get(peerId);
            if (peerSessions == null || peerSessions.isEmpty()) continue;
            if (!chatService.canViewPresence(actorId, peerId)) continue;

            ServerEvent event = new ServerEvent(
                    envelope.eventId(), "PRESENCE_UPDATED", "PRESENCE_CHANGED",
                    null, null, null, null, actor, null, null, null,
                    envelope.online(), null, null, null, envelope.occurredAt());
            for (String sessionId : peerSessions) {
                SessionState state = sessionsById.get(sessionId);
                if (state != null) sendToSession(state.session(), event);
            }
        }
    }

    public boolean isUserOnline(UUID userId) {
        if (userId == null) return false;
        Set<String> local = sessionIdsByUser.get(userId);
        if (local != null && !local.isEmpty()) return true;
        if (redisTemplate != null) {
            try {
                Long size = redisTemplate.opsForSet().size(redisUserSessionsKey(userId));
                return size != null && size > 0;
            } catch (Exception ignored) { }
        }
        return false;
    }

    public boolean isUserTyping(UUID conversationId, UUID userId) {
        Instant exp = activeTypings.get(new TypingKey(conversationId, userId));
        if (exp != null && Instant.now().isBefore(exp)) return true;
        if (redisTemplate != null) {
            try {
                return Boolean.TRUE.equals(redisTemplate.hasKey(redisTypingKey(conversationId, userId)));
            } catch (Exception ignored) { }
        }
        return false;
    }

    private List<UUID> visibleOnlineParticipants(UUID conversationId, UUID viewerUserId) {
        Set<UUID> participants = chatService.eligibleRecipientUserIds(conversationId);
        List<UUID> online = new ArrayList<>();
        for (UUID participantId : participants) {
            if (!participantId.equals(viewerUserId)
                    && isUserOnline(participantId)
                    && chatService.canViewPresence(participantId, viewerUserId)) {
                online.add(participantId);
            }
        }
        return online;
    }

    private void clearAllTypingForUser(UUID userId) {
        for (TypingKey key : new ArrayList<>(activeTypings.keySet())) {
            if (userId.equals(key.userId())) {
                activeTypings.remove(key);
                writeRedisTypingKey(key.conversationId(), userId, false);
            }
        }
    }

    private void recordRedisSessionConnect(UUID userId, String sessionId) {
        if (redisTemplate == null) return;
        try {
            String userKey = redisUserSessionsKey(userId);
            String sessionKey = redisSessionUserKey(sessionId);
            redisTemplate.opsForSet().add(userKey, sessionId);
            redisTemplate.expire(userKey, PRESENCE_TTL);
            redisTemplate.opsForValue().set(sessionKey, userId.toString(), PRESENCE_TTL);
        } catch (Exception ignored) { }
    }

    private void refreshRedisSessionPresence(UUID userId, String sessionId) {
        if (redisTemplate == null) return;
        try {
            redisTemplate.expire(redisUserSessionsKey(userId), PRESENCE_TTL);
            redisTemplate.expire(redisSessionUserKey(sessionId), PRESENCE_TTL);
        } catch (Exception ignored) { }
    }

    private void recordRedisSessionDisconnect(UUID userId, String sessionId) {
        if (redisTemplate == null) return;
        try {
            String userKey = redisUserSessionsKey(userId);
            redisTemplate.opsForSet().remove(userKey, sessionId);
            redisTemplate.delete(redisSessionUserKey(sessionId));
        } catch (Exception ignored) { }
    }

    private void writeRedisTypingKey(UUID conversationId, UUID userId, boolean typing) {
        if (redisTemplate == null) return;
        try {
            String key = redisTypingKey(conversationId, userId);
            if (typing) {
                redisTemplate.opsForValue().set(key, "1", TYPING_TTL);
            } else {
                redisTemplate.delete(key);
            }
        } catch (Exception ignored) { }
    }

    public static String redisTypingKey(UUID conversationId, UUID userId) {
        return "typing:" + conversationId + ":" + userId;
    }

    public static String redisUserSessionsKey(UUID userId) {
        return "presence:user:" + userId + ":sessions";
    }

    public static String redisSessionUserKey(String sessionId) {
        return "presence:session:" + sessionId;
    }

    private ChatResponses.User safeUserSummary(UUID userId) {
        try {
            return chatService.userSummary(userId);
        } catch (RuntimeException ex) {
            return new ChatResponses.User(userId, "Người dùng", null);
        }
    }

    private void sendError(WebSocketSession session, UUID conversationId, String code, String message) {
        sendToSession(session, new ServerEvent(
                UUID.randomUUID(), "ERROR", null, conversationId, null, null, null,
                null, null, null, null, null, null, code, message, Instant.now()));
    }

    private void sendToSession(WebSocketSession session, ServerEvent event) {
        if (session == null || !session.isOpen()) return;
        try {
            String json = objectMapper.writeValueAsString(event);
            synchronized (session) {
                if (session.isOpen()) {
                    session.sendMessage(new TextMessage(json));
                }
            }
        } catch (IOException | RuntimeException ignored) { }
    }

    private record TypingKey(UUID conversationId, UUID userId) { }

    private record SessionState(
            WebSocketSession session,
            UUID userId,
            Set<UUID> subscribedConversations
    ) {
        SessionState(WebSocketSession session, UUID userId) {
            this(session, userId, ConcurrentHashMap.newKeySet());
        }
    }
}
