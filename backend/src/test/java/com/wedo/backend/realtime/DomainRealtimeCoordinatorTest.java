package com.wedo.backend.realtime;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.wedo.backend.common.event.PostCommitDelivery;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.context.annotation.AnnotationConfigApplicationContext;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.event.TransactionalEventListenerFactory;
import org.springframework.transaction.support.AbstractPlatformTransactionManager;
import org.springframework.transaction.support.DefaultTransactionStatus;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;

class DomainRealtimeCoordinatorTest {
    private final ObjectMapper mapper = new ObjectMapper().findAndRegisterModules();
    private final RealtimeScopeAccess access = mock(RealtimeScopeAccess.class);
    private final PostCommitDelivery delivery = mock(PostCommitDelivery.class);
    private final DomainRealtimeCoordinator coordinator = new DomainRealtimeCoordinator(mapper, access, delivery, null);
    private final UUID user = UUID.randomUUID(), group = UUID.randomUUID(), activity = UUID.randomUUID();

    private WebSocketSession socket(String id) {
        WebSocketSession socket = mock(WebSocketSession.class);
        when(socket.getId()).thenReturn(id);
        when(socket.isOpen()).thenReturn(true);
        coordinator.register(socket, user);
        return socket;
    }

    @Test void scopedDeliveryDeduplicatesAndExcludesUnsubscribedSessions() throws Exception {
        var subscribed = socket("subscribed");
        var other = socket("other");
        String scope = "activity:" + activity;
        when(access.allowed(scope, user)).thenReturn(true);
        assertTrue(coordinator.command(subscribed, "{\"type\":\"SUBSCRIBE_SCOPE\",\"scope\":\"" + scope + "\"}"));
        clearInvocations(subscribed, other);
        var event = DomainRealtimeEvent.changed("ACTIVITY_RSVP_CHANGED", "ACTIVITY", activity, group, user, scope);
        coordinator.receive(event);
        coordinator.receive(event);
        verify(subscribed, times(1)).sendMessage(any(TextMessage.class));
        verify(other, never()).sendMessage(any());
    }

    @Test void groupSubscriberReceivesRelatedActivityInvalidation() throws Exception {
        var socket = socket("group");
        when(access.allowed("group:" + group, user)).thenReturn(true);
        coordinator.command(socket, "{\"type\":\"SUBSCRIBE_SCOPE\",\"scope\":\"group:" + group + "\"}");
        clearInvocations(socket);
        coordinator.receive(DomainRealtimeEvent.changed("ACTIVITY_RSVP_CHANGED", "ACTIVITY", activity, group, user, "activity:" + activity));
        verify(socket).sendMessage(any(TextMessage.class));
    }

    @Test void redisFanoutReusesTheSameEventIdAndSuppressesLocalEchoAndRemoteDuplicates() throws Exception {
        var redis = mock(org.springframework.data.redis.core.StringRedisTemplate.class);
        var publisher = new DomainRealtimeCoordinator(mapper, access, delivery, redis);
        var remote = new DomainRealtimeCoordinator(mapper, access, delivery, null);
        var socket = mock(WebSocketSession.class);
        when(socket.getId()).thenReturn("remote");
        when(socket.isOpen()).thenReturn(true);
        String scope = "activity:" + activity;
        when(access.allowed(scope, user)).thenReturn(true);
        remote.register(socket, user);
        remote.command(socket, "{\"type\":\"SUBSCRIBE_SCOPE\",\"scope\":\"" + scope + "\"}");
        clearInvocations(socket);
        var event = DomainRealtimeEvent.changed("POLL_VOTE_CHANGED", "POLL", UUID.randomUUID(), null, null, scope);
        publisher.publish(event);
        var json = ArgumentCaptor.forClass(String.class);
        verify(redis).convertAndSend(eq(DomainRealtimeCoordinator.CHANNEL), json.capture());
        remote.onRedisMessage(json.getValue());
        remote.onRedisMessage(json.getValue());
        verify(socket, times(1)).sendMessage(any(TextMessage.class));
    }

    @Test void queuedJoinRequestInvalidationRechecksAdminRoleBeforeDelivery() throws Exception {
        var socket = socket("former-admin");
        String scope = "user:" + user;
        when(access.allowed(scope, user)).thenReturn(true);
        coordinator.command(socket, "{\"type\":\"SUBSCRIBE_SCOPE\",\"scope\":\"user:self\"}");
        clearInvocations(socket);
        coordinator.receive(DomainRealtimeEvent.changed("GROUP_JOIN_REQUESTED", "GROUP", group, null, null, scope));
        var frames = ArgumentCaptor.forClass(TextMessage.class);
        verify(socket).sendMessage(frames.capture());
        assertTrue(frames.getValue().getPayload().contains("SCOPE_RESYNC"));
        assertFalse(frames.getValue().getPayload().contains("GROUP_JOIN_REQUESTED"));
    }

    @Test void unauthorizedSubscriptionDeniedAndMembershipLossRevokesExistingSubscription() throws Exception {
        var socket = socket("revoked");
        String scope = "group:" + group;
        coordinator.command(socket, "{\"type\":\"SUBSCRIBE_SCOPE\",\"scope\":\"" + scope + "\"}");
        ArgumentCaptor<TextMessage> frames = ArgumentCaptor.forClass(TextMessage.class);
        verify(socket).sendMessage(frames.capture());
        assertTrue(frames.getValue().getPayload().contains("SCOPE_DENIED"));
        when(access.allowed(scope, user)).thenReturn(true);
        coordinator.command(socket, "{\"type\":\"SUBSCRIBE_SCOPE\",\"scope\":\"" + scope + "\"}");
        when(access.allowed(scope, user)).thenReturn(false);
        clearInvocations(socket);
        coordinator.receive(DomainRealtimeEvent.changed("GROUP_MEMBER_LEFT", "GROUP", group, group, null, scope));
        verify(socket).sendMessage(frames.capture());
        assertTrue(frames.getValue().getPayload().contains("SCOPE_REVOKED"));
        assertFalse(frames.getValue().getPayload().contains("DOMAIN_CHANGED"));
    }

    @Test void onlyCommitEnqueuesDeliveryNeverRollbackOrNontransactionalPublication() {
        try (var context = new AnnotationConfigApplicationContext()) {
            context.registerBean(TransactionalEventListenerFactory.class);
            context.registerBean(DomainRealtimeCoordinator.class, () -> coordinator);
            context.refresh();
            var publisher = new RealtimePublisher(context);
            var tx = new TransactionTemplate(new MemoryTransactions());
            tx.executeWithoutResult(status -> {
                publisher.group("GROUP_UPDATED", group, user);
                verifyNoInteractions(delivery);
            });
            verify(delivery, times(1)).submit(eq("domain-realtime"), eq(group), any(Runnable.class));
            clearInvocations(delivery);
            tx.executeWithoutResult(status -> {
                publisher.group("GROUP_UPDATED", group, user);
                status.setRollbackOnly();
            });
            verifyNoInteractions(delivery);
            assertThrows(IllegalStateException.class, () -> publisher.group("GROUP_UPDATED", group, user));
            tx.setReadOnly(true);
            tx.executeWithoutResult(status -> assertThrows(IllegalStateException.class,
                    () -> publisher.group("GROUP_UPDATED", group, user)));
        }
    }

    private static class MemoryTransactions extends AbstractPlatformTransactionManager {
        @Override protected Object doGetTransaction() { return new Object(); }
        @Override protected void doBegin(Object transaction, TransactionDefinition definition) { }
        @Override protected void doCommit(DefaultTransactionStatus status) { }
        @Override protected void doRollback(DefaultTransactionStatus status) { }
    }
}
