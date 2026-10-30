package com.wedo.backend.chat.realtime;

import java.util.UUID;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

@Component
public class ChatWebSocketHandler extends TextWebSocketHandler {
    private final ChatRealtimeCoordinator coordinator;
    @org.springframework.beans.factory.annotation.Autowired
    private com.wedo.backend.realtime.DomainRealtimeCoordinator domain;

    public ChatWebSocketHandler(ChatRealtimeCoordinator coordinator) {
        this.coordinator = coordinator;
    }

    @Override
    public void afterConnectionEstablished(WebSocketSession session) throws Exception {
        Object attr = session.getAttributes().get(ChatWebSocketHandshakeInterceptor.USER_ID_ATTR);
        if (!(attr instanceof UUID userId)) {
            session.close(CloseStatus.POLICY_VIOLATION);
            return;
        }
        coordinator.registerSession(session, userId);
        domain.register(session, userId);
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) {
        if (!domain.command(session, message.getPayload())) {
            coordinator.handleClientCommand(session, message.getPayload());
        }
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        coordinator.unregisterSession(session);
        domain.unregister(session);
    }

    @Override
    public void handleTransportError(WebSocketSession session, Throwable exception) throws Exception {
        coordinator.unregisterSession(session);
        domain.unregister(session);
        if (session.isOpen()) {
            session.close(CloseStatus.SERVER_ERROR);
        }
    }
}
