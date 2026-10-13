package com.wedo.backend.chat;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.wedo.backend.chat.dto.ChatResponses;
import com.wedo.backend.chat.realtime.ChatRealtimeCoordinator;
import com.wedo.backend.chat.realtime.ChatRealtimeEvents.RedisFanoutEnvelope;
import com.wedo.backend.chat.service.ChatService;
import java.io.IOException;
import java.time.Instant;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.WebSocketMessage;

class ChatDeliveryFailureTest {
    @Test
    void redisFailureKeepsLocalDeliveryAndReplayDedupAndSocketFailureContained() throws Exception {
        ChatService chat = mock(ChatService.class);
        StringRedisTemplate redis = mock(StringRedisTemplate.class);
        UUID viewer = UUID.randomUUID(), conversation = UUID.randomUUID();
        when(chat.userSummary(viewer)).thenReturn(new ChatResponses.User(viewer,"Fixture",null));
        when(chat.eligibleRecipientUserIds(conversation)).thenReturn(Set.of(viewer));
        when(chat.canSubscribeConversation(conversation,viewer)).thenReturn(true);
        WebSocketSession session = mock(WebSocketSession.class);
        when(session.getId()).thenReturn("test-session");
        when(session.isOpen()).thenReturn(true);
        ChatRealtimeCoordinator coordinator = new ChatRealtimeCoordinator(chat,new ObjectMapper().findAndRegisterModules(),redis);
        coordinator.registerSession(session,viewer);
        clearInvocations(session);
        doThrow(new IllegalStateException("Provider payload must not be logged"))
                .when(redis).convertAndSend(anyString(),anyString());
        RedisFanoutEnvelope event = new RedisFanoutEnvelope(UUID.randomUUID(),"test","READ_STATE_UPDATED",
                conversation,null,1L,null,viewer,null,null,null,Instant.now());
        assertDoesNotThrow(() -> coordinator.publishAndDeliver(event));
        coordinator.publishAndDeliver(event);
        verify(session,times(1)).sendMessage(any(WebSocketMessage.class));
        doThrow(new IOException("Socket payload must not be logged")).when(session).sendMessage(any());
        assertDoesNotThrow(() -> coordinator.publishAndDeliver(new RedisFanoutEnvelope(UUID.randomUUID(),"test",
                "READ_STATE_UPDATED",conversation,null,2L,null,viewer,null,null,null,Instant.now())));
    }
}
