package com.wedo.backend.realtime;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;
import static org.junit.jupiter.api.Assertions.*;
import java.time.Duration;
import java.util.UUID;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import org.awaitility.Awaitility;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;

/** In-process transport probe; uses real production subscription authorization. */
public final class RealtimeProbe implements AutoCloseable {
    private final DomainRealtimeCoordinator coordinator;
    private final WebSocketSession socket;
    public final List<String> frames = new CopyOnWriteArrayList<>();

    public RealtimeProbe(DomainRealtimeCoordinator coordinator, UUID userId, String scope) throws Exception {
        this.coordinator = coordinator;
        socket = mock(WebSocketSession.class);
        when(socket.getId()).thenReturn("realtime-probe-" + UUID.randomUUID());
        when(socket.isOpen()).thenReturn(true);
        doAnswer(call -> { frames.add(((TextMessage) call.getArgument(0)).getPayload()); return null; })
                .when(socket).sendMessage(any());
        coordinator.register(socket, userId);
        coordinator.command(socket, "{\"type\":\"SUBSCRIBE_SCOPE\",\"scope\":\"" + scope + "\"}");
        assertTrue(frames.stream().anyMatch(frame -> frame.contains("SCOPE_SUBSCRIBED")), "Probe must be authorized");
        frames.clear();
    }

    public String await(String type) {
        Awaitility.await().atMost(Duration.ofSeconds(10)).until(() ->
                frames.stream().anyMatch(frame -> frame.contains("\"eventType\":\"" + type + "\"")));
        return frames.stream().filter(frame -> frame.contains("\"eventType\":\"" + type + "\"")).findFirst().orElseThrow();
    }

    @Override public void close() { coordinator.unregister(socket); }
}
