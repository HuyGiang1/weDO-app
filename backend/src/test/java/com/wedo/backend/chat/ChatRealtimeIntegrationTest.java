package com.wedo.backend.chat;

import static org.junit.jupiter.api.Assertions.*;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.wedo.backend.chat.dto.ChatRequests;
import com.wedo.backend.chat.dto.ChatResponses;
import com.wedo.backend.chat.realtime.ChatRealtimeCoordinator;
import com.wedo.backend.chat.realtime.ChatRealtimeEvents.RedisFanoutEnvelope;
import com.wedo.backend.chat.realtime.ChatRealtimeEvents.ServerEvent;
import com.wedo.backend.chat.service.ChatService;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.group.entity.GroupEntity;
import com.wedo.backend.group.entity.GroupMembershipEntity;
import com.wedo.backend.group.entity.GroupMembershipStatus;
import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.entity.GroupSettingsEntity;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.group.repository.GroupMembershipRepository;
import com.wedo.backend.group.repository.GroupRepository;
import com.wedo.backend.group.repository.GroupSettingsRepository;
import com.wedo.backend.security.jwt.JwtService;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserRepository;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.WebSocket;
import java.net.http.WebSocketHandshakeException;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.CompletionException;
import java.util.concurrent.CompletionStage;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.jdbc.core.JdbcTemplate;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class ChatRealtimeIntegrationTest extends AbstractPostgresIntegrationTest {

    @LocalServerPort
    int port;

    @Autowired ChatService chatService;
    @Autowired ChatRealtimeCoordinator coordinator;
    @Autowired JwtService jwtService;
    @Autowired ObjectMapper objectMapper;
    @Autowired UserRepository users;
    @Autowired GroupRepository groups;
    @Autowired GroupMembershipRepository memberships;
    @Autowired GroupSettingsRepository settings;
    @Autowired JdbcTemplate jdbc;

    @Test
    void rejectsUnauthenticatedHandshakeAndAllowsAuthenticatedHeaderOrQueryToken() throws Exception {
        Fixture f = fixture();
        HttpClient http = HttpClient.newHttpClient();

        // 1. Unauthenticated connection must fail handshake (401)
        CompletionException unauthEx = assertThrows(CompletionException.class, () ->
                http.newWebSocketBuilder()
                        .buildAsync(URI.create("ws://localhost:" + port + "/ws"), new TestWsListener(objectMapper))
                        .join());
        assertInstanceOf(WebSocketHandshakeException.class, unauthEx.getCause());
        assertEquals(401, ((WebSocketHandshakeException) unauthEx.getCause()).getResponse().statusCode());

        // 2. Invalid JWT must fail handshake (401)
        CompletionException invalidEx = assertThrows(CompletionException.class, () ->
                http.newWebSocketBuilder()
                        .header("Authorization", "Bearer invalid.jwt.token")
                        .buildAsync(URI.create("ws://localhost:" + port + "/ws"), new TestWsListener(objectMapper))
                        .join());
        assertInstanceOf(WebSocketHandshakeException.class, invalidEx.getCause());
        assertEquals(401, ((WebSocketHandshakeException) invalidEx.getCause()).getResponse().statusCode());

        // 3. Authenticated Bearer header succeeds and receives CONNECTED
        try (TestWsClient ownerClient = connectBearer(f.ownerA)) {
            ServerEvent connected = ownerClient.awaitEvent("CONNECTED");
            assertNotNull(connected);
            assertEquals(f.ownerA, connected.actor().id());
        }

        // 4. Authenticated query param (?access_token=...) succeeds and receives CONNECTED
        try (TestWsClient adminClient = connectQuery(f.adminB)) {
            ServerEvent connected = adminClient.awaitEvent("CONNECTED");
            assertNotNull(connected);
            assertEquals(f.adminB, connected.actor().id());
        }
    }

    @Test
    void multiAccountRealtimeDeliveryEditReactionUnsendReadTypingAndOutsiderIsolation() throws Exception {
        Fixture f = fixture();
        ChatResponses.Conversation groupConv = chatService.openGroup(f.groupId, f.ownerA);

        try (TestWsClient ownerWs = connectBearer(f.ownerA);
             TestWsClient adminWs = connectBearer(f.adminB);
             TestWsClient memberWs = connectBearer(f.memberC);
             TestWsClient outsiderWs = connectBearer(f.outsiderE)) {

            ownerWs.awaitEvent("CONNECTED");
            adminWs.awaitEvent("CONNECTED");
            memberWs.awaitEvent("CONNECTED");
            outsiderWs.awaitEvent("CONNECTED");

            // Subscribe eligible participants
            ownerWs.sendJson("{\"type\":\"SUBSCRIBE\",\"conversationId\":\"" + groupConv.id() + "\"}");
            adminWs.sendJson("{\"type\":\"SUBSCRIBE\",\"conversationId\":\"" + groupConv.id() + "\"}");
            memberWs.sendJson("{\"type\":\"SUBSCRIBE\",\"conversationId\":\"" + groupConv.id() + "\"}");

            assertEquals("SUBSCRIBED", ownerWs.awaitEvent("SUBSCRIBED").type());
            assertEquals("SUBSCRIBED", adminWs.awaitEvent("SUBSCRIBED").type());
            assertEquals("SUBSCRIBED", memberWs.awaitEvent("SUBSCRIBED").type());

            // Outsider subscription attempt must be denied (anti-IDOR)
            outsiderWs.sendJson("{\"type\":\"SUBSCRIBE\",\"conversationId\":\"" + groupConv.id() + "\"}");
            ServerEvent outsiderError = outsiderWs.awaitEvent("ERROR");
            assertEquals("ACCESS_DENIED", outsiderError.errorCode());

            // Outsider typing attempt must be denied
            outsiderWs.sendJson("{\"type\":\"TYPING_START\",\"conversationId\":\"" + groupConv.id() + "\"}");
            assertEquals("ACCESS_DENIED", outsiderWs.awaitEvent("ERROR").errorCode());

            // Admin B starts typing -> Owner A & Member C receive TYPING_UPDATED (USER_TYPING), Outsider does not
            adminWs.sendJson("{\"type\":\"TYPING_START\",\"conversationId\":\"" + groupConv.id() + "\"}");
            ServerEvent typingStart = ownerWs.awaitEvent("TYPING_UPDATED");
            assertEquals(Boolean.TRUE, typingStart.typing());
            assertEquals("USER_TYPING", typingStart.eventAlias());
            assertEquals(f.adminB, typingStart.actor().id());
            assertTrue(coordinator.isUserTyping(groupConv.id(), f.adminB));

            // 1. Owner A sends via REST with clientMessageId -> AFTER_COMMIT emits MESSAGE_CREATED
            UUID clientMsgId = UUID.randomUUID();
            ChatResponses.Message sent = chatService.send(
                    groupConv.id(),
                    f.ownerA,
                    new ChatRequests.SendMessage("Chào cả nhóm M10", null, clientMsgId)
            );

            ServerEvent ownerMsgEvent = ownerWs.awaitEvent("MESSAGE_CREATED");
            assertEquals(sent.id(), ownerMsgEvent.messageId());
            assertEquals(clientMsgId, ownerMsgEvent.clientMessageId());
            assertTrue(ownerMsgEvent.message().isMine());

            ServerEvent adminMsgEvent = adminWs.awaitEvent("MESSAGE_CREATED");
            assertEquals(sent.id(), adminMsgEvent.messageId());
            assertEquals(clientMsgId, adminMsgEvent.clientMessageId());
            assertFalse(adminMsgEvent.message().isMine());
            assertEquals("Chào cả nhóm M10", adminMsgEvent.message().content());

            ServerEvent memberMsgEvent = memberWs.awaitEvent("MESSAGE_CREATED");
            assertEquals(sent.id(), memberMsgEvent.messageId());
            assertFalse(memberMsgEvent.message().isMine());

            // Outsider E must receive nothing
            assertNull(outsiderWs.pollEvent("MESSAGE_CREATED", 250));

            // 2. Rolled-back mutation (blank message) emits NO event
            assertThrows(BusinessException.class, () ->
                    chatService.send(groupConv.id(), f.ownerA, new ChatRequests.SendMessage("   ", null)));
            assertNull(adminWs.pollEvent("MESSAGE_CREATED", 200));

            // 3. Edit propagation
            chatService.edit(sent.id(), f.ownerA, new ChatRequests.EditMessage("Chào cả nhóm M10 (đã sửa)"));
            ServerEvent editEvent = adminWs.awaitEvent("MESSAGE_EDITED");
            assertEquals(sent.id(), editEvent.messageId());
            assertEquals("Chào cả nhóm M10 (đã sửa)", editEvent.message().content());
            assertNotNull(editEvent.message().editedAt());

            // 4. Reaction propagation (viewer-scoped myReaction)
            chatService.react(sent.id(), f.adminB, new ChatRequests.Reaction("❤️"));
            ServerEvent ownerReactionEvent = ownerWs.awaitEvent("MESSAGE_REACTION_UPDATED");
            assertEquals("REACTION_UPDATED", ownerReactionEvent.eventAlias());
            assertNull(ownerReactionEvent.message().myReaction());
            assertEquals(1, ownerReactionEvent.message().reactions().size());
            assertEquals("❤️", ownerReactionEvent.message().reactions().get(0).emoji());

            ServerEvent adminReactionEvent = adminWs.awaitEvent("MESSAGE_REACTION_UPDATED");
            assertEquals("❤️", adminReactionEvent.message().myReaction());

            // 5. Read receipt propagation
            chatService.read(groupConv.id(), f.adminB, sent.sequence());
            ServerEvent readEvent = ownerWs.awaitEvent("READ_STATE_UPDATED");
            assertEquals("MESSAGE_READ", readEvent.eventAlias());
            assertEquals(f.adminB, readEvent.reader().userId());
            assertEquals(sent.sequence(), readEvent.reader().lastReadSequence());

            // 6. Unsend propagation -> status UNSENT, content null, reactions empty
            chatService.unsend(sent.id(), f.ownerA);
            ServerEvent unsendEvent = adminWs.awaitEvent("MESSAGE_UNSENT");
            assertEquals("UNSENT", unsendEvent.message().status());
            assertNull(unsendEvent.message().content());
            assertTrue(unsendEvent.message().reactions().isEmpty());
        }
    }

    @Test
    void durableMessageMutationsAreRejectedOverWebSocket() throws Exception {
        Fixture f = fixture();
        ChatResponses.Conversation conversation = chatService.openGroup(f.groupId, f.ownerA);

        try (TestWsClient client = connectBearer(f.ownerA)) {
            client.awaitEvent("CONNECTED");
            client.sendJson("{\"type\":\"SEND_MESSAGE\",\"conversationId\":\"" + conversation.id()
                    + "\",\"content\":\"must use REST\"}");

            ServerEvent error = client.awaitEvent("ERROR");
            assertEquals("VALIDATION_FAILED", error.errorCode());
            assertTrue(error.errorMessage().contains("Unsupported command"));
            assertTrue(chatService.history(conversation.id(), f.ownerA, null, 50).messages().isEmpty());
        }
    }

    @Test
    void multiSessionPresenceTracksMultipleSocketsAndPersistsSnapshotOnlyAfterLastClose() throws Exception {
        Fixture f = fixture();
        chatService.openGroup(f.groupId, f.ownerA);

        try (TestWsClient adminWs = connectBearer(f.adminB)) {
            adminWs.awaitEvent("CONNECTED");

            TestWsClient ownerSession1 = connectBearer(f.ownerA);
            ownerSession1.awaitEvent("CONNECTED");
            assertTrue(coordinator.isUserOnline(f.ownerA));

            ServerEvent onlineEvent = adminWs.awaitEvent("PRESENCE_UPDATED");
            assertEquals(f.ownerA, onlineEvent.actor().id());
            assertEquals(Boolean.TRUE, onlineEvent.online());

            // Second session for Owner A
            TestWsClient ownerSession2 = connectBearer(f.ownerA);
            ownerSession2.awaitEvent("CONNECTED");
            assertTrue(coordinator.isUserOnline(f.ownerA));

            // Close first session -> Owner A must remain online (no offline event)
            ownerSession1.close();
            Thread.sleep(200);
            assertTrue(coordinator.isUserOnline(f.ownerA));
            assertNull(adminWs.pollEvent("PRESENCE_UPDATED", 200));

            // Close second (last) session -> Owner A goes offline, emits PRESENCE_UPDATED(false), writes snapshot
            ownerSession2.close();
            ServerEvent offlineEvent = adminWs.awaitEvent("PRESENCE_UPDATED");
            assertEquals(f.ownerA, offlineEvent.actor().id());
            assertEquals(Boolean.FALSE, offlineEvent.online());
            assertFalse(coordinator.isUserOnline(f.ownerA));

            Long snapshotCount = jdbc.queryForObject(
                    "SELECT count(*) FROM user_presence_snapshots WHERE user_id=? AND last_seen_at IS NOT NULL",
                    Long.class, f.ownerA);
            assertEquals(1L, snapshotCount);
        }
    }

    @Test
    void deduplicatesRedisFanoutEnvelopeByEventId() throws Exception {
        Fixture f = fixture();
        ChatResponses.Conversation groupConv = chatService.openGroup(f.groupId, f.ownerA);
        ChatResponses.Message msg = chatService.send(groupConv.id(), f.ownerA, new ChatRequests.SendMessage("Dedup test", null));

        try (TestWsClient adminWs = connectBearer(f.adminB)) {
            adminWs.awaitEvent("CONNECTED");
            adminWs.sendJson("{\"type\":\"SUBSCRIBE\",\"conversationId\":\"" + groupConv.id() + "\"}");
            adminWs.awaitEvent("SUBSCRIBED");

            UUID duplicateEventId = UUID.randomUUID();
            RedisFanoutEnvelope env = new RedisFanoutEnvelope(
                    duplicateEventId, "remote-instance", "MESSAGE_EDITED",
                    groupConv.id(), msg.id(), msg.sequence(), null, f.ownerA,
                    null, null, null, Instant.now());
            String rawJson = objectMapper.writeValueAsString(env);

            // Deliver first time -> delivered
            coordinator.onRedisMessage(rawJson);
            assertNotNull(adminWs.awaitEvent("MESSAGE_EDITED"));

            // Deliver second time with same eventId -> deduplicated (not delivered again)
            coordinator.onRedisMessage(rawJson);
            assertNull(adminWs.pollEvent("MESSAGE_EDITED", 200));
        }
    }

    private TestWsClient connectBearer(UUID userId) {
        String token = jwtService.generateAccessToken(userId);
        TestWsListener listener = new TestWsListener(objectMapper);
        WebSocket ws = HttpClient.newHttpClient()
                .newWebSocketBuilder()
                .header("Authorization", "Bearer " + token)
                .buildAsync(URI.create("ws://localhost:" + port + "/ws"), listener)
                .join();
        return new TestWsClient(ws, listener);
    }

    private TestWsClient connectQuery(UUID userId) {
        String token = jwtService.generateAccessToken(userId);
        TestWsListener listener = new TestWsListener(objectMapper);
        WebSocket ws = HttpClient.newHttpClient()
                .newWebSocketBuilder()
                .buildAsync(URI.create("ws://localhost:" + port + "/ws?access_token=" + token), listener)
                .join();
        return new TestWsClient(ws, listener);
    }

    private Fixture fixture() {
        UUID ownerA = createUser("OWNER_A");
        UUID adminB = createUser("ADMIN_B");
        UUID memberC = createUser("MEMBER_C");
        UUID memberD = createUser("MEMBER_D");
        UUID outsiderE = createUser("OUTSIDER_E");
        Instant now = Instant.now();
        UUID groupId = UUID.randomUUID();
        GroupEntity group = new GroupEntity(groupId, "Nhóm Realtime M10", "Mô tả", null, GroupStatus.ACTIVE, ownerA, now, now);
        groups.save(group);
        settings.save(GroupSettingsEntity.createDefault(groupId, now));
        memberships.save(new GroupMembershipEntity(UUID.randomUUID(), groupId, ownerA, GroupRole.OWNER, GroupMembershipStatus.ACTIVE, now, null));
        memberships.save(new GroupMembershipEntity(UUID.randomUUID(), groupId, adminB, GroupRole.ADMIN, GroupMembershipStatus.ACTIVE, now, null));
        memberships.save(new GroupMembershipEntity(UUID.randomUUID(), groupId, memberC, GroupRole.MEMBER, GroupMembershipStatus.ACTIVE, now, null));
        memberships.save(new GroupMembershipEntity(UUID.randomUUID(), groupId, memberD, GroupRole.MEMBER, GroupMembershipStatus.ACTIVE, now, null));
        return new Fixture(ownerA, adminB, memberC, memberD, outsiderE, groupId);
    }

    private UUID createUser(String name) {
        UUID id = UUID.randomUUID();
        String suffix = id.toString().substring(0, 8);
        Instant now = Instant.now();
        users.save(new UserEntity(id, "u_" + suffix, "u_" + suffix + "@wedo.local", name, UserStatus.ACTIVE, now, now));
        return id;
    }

    private record Fixture(UUID ownerA, UUID adminB, UUID memberC, UUID memberD, UUID outsiderE, UUID groupId) { }

    private static final class TestWsListener implements WebSocket.Listener {
        private final ObjectMapper mapper;
        private final BlockingQueue<ServerEvent> events = new LinkedBlockingQueue<>();
        private final StringBuilder buffer = new StringBuilder();

        TestWsListener(ObjectMapper mapper) {
            this.mapper = mapper;
        }

        @Override
        public CompletionStage<?> onText(WebSocket webSocket, CharSequence data, boolean last) {
            buffer.append(data);
            if (last) {
                String json = buffer.toString();
                buffer.setLength(0);
                try {
                    events.offer(mapper.readValue(json, ServerEvent.class));
                } catch (Exception ignored) { }
            }
            webSocket.request(1);
            return null;
        }
    }

    private static final class TestWsClient implements AutoCloseable {
        private final WebSocket ws;
        private final TestWsListener listener;
        private final List<ServerEvent> unmatched = new ArrayList<>();

        TestWsClient(WebSocket ws, TestWsListener listener) {
            this.ws = ws;
            this.listener = listener;
        }

        void sendJson(String json) {
            ws.sendText(json, true).join();
        }

        ServerEvent awaitEvent(String expectedType) throws InterruptedException {
            ServerEvent event = pollEvent(expectedType, 5000);
            assertNotNull(event, "Timed out waiting for WebSocket event type: " + expectedType);
            return event;
        }

        ServerEvent pollEvent(String expectedType, long timeoutMs) throws InterruptedException {
            for (int i = 0; i < unmatched.size(); i++) {
                if (expectedType.equals(unmatched.get(i).type())) {
                    return unmatched.remove(i);
                }
            }
            long deadline = System.currentTimeMillis() + timeoutMs;
            while (System.currentTimeMillis() < deadline) {
                long remaining = Math.max(1, deadline - System.currentTimeMillis());
                ServerEvent next = listener.events.poll(remaining, TimeUnit.MILLISECONDS);
                if (next == null) return null;
                if (expectedType.equals(next.type())) return next;
                unmatched.add(next);
            }
            return null;
        }

        @Override
        public void close() {
            try {
                ws.sendClose(WebSocket.NORMAL_CLOSURE, "done").join();
            } catch (Exception ignored) { }
        }
    }
}
