package com.wedo.backend.realtime;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.wedo.backend.common.event.PostCommitDelivery;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;

/** Domain subscriptions share the existing authenticated Chat socket and Redis connection. */
@Component
public class DomainRealtimeCoordinator {
    public static final String CHANNEL = "wedo:domain:realtime";
    private static final org.slf4j.Logger log = org.slf4j.LoggerFactory.getLogger(DomainRealtimeCoordinator.class);
    private final ObjectMapper mapper;
    private final RealtimeScopeAccess access;
    private final PostCommitDelivery delivery;
    private final StringRedisTemplate redis;
    private final Map<String, Session> sessions = new ConcurrentHashMap<>();
    private final Map<UUID, Boolean> seen = new LinkedHashMap<>();

    public DomainRealtimeCoordinator(ObjectMapper mapper, RealtimeScopeAccess access,
            PostCommitDelivery delivery, @Autowired(required = false) StringRedisTemplate redis) {
        this.mapper = mapper; this.access = access; this.delivery = delivery; this.redis = redis;
    }

    public void register(WebSocketSession socket, UUID userId) {
        sessions.put(socket.getId(), new Session(socket, userId, ConcurrentHashMap.newKeySet(), new ConcurrentHashMap<>()));
    }

    public void unregister(WebSocketSession socket) { sessions.remove(socket.getId()); }

    public boolean command(WebSocketSession socket, String raw) {
        try {
            var frame = mapper.readTree(raw);
            String type = frame.path("type").asText();
            if (!type.equals("SUBSCRIBE_SCOPE") && !type.equals("UNSUBSCRIBE_SCOPE")) return false;
            Session session = sessions.get(socket.getId());
            if (session == null) return true;
            String scope = frame.path("scope").asText();
            if (scope.equals("user:self")) scope = "user:" + session.userId;
            if (type.equals("UNSUBSCRIBE_SCOPE")) {
                session.scopes.remove(scope);
                session.groups.remove(scope);
                send(socket, Map.of("type", "SCOPE_UNSUBSCRIBED", "scope", scope));
            } else if (session.scopes.size() < 100 && access.allowed(scope, session.userId)) {
                UUID group = access.groupForScope(scope, session.userId);
                session.scopes.add(scope);
                if (group != null) session.groups.put(scope, group);
                send(socket, Map.of("type", "SCOPE_SUBSCRIBED", "scope", scope));
            } else {
                session.scopes.remove(scope);
                send(socket, Map.of("type", "SCOPE_DENIED", "scope", scope, "errorCode", "ACCESS_DENIED"));
            }
            return true;
        } catch (Exception invalid) { return false; }
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void afterCommit(DomainRealtimeEvent event) {
        delivery.submit("domain-realtime", event.aggregateId(), () -> publish(event));
    }

    void publish(DomainRealtimeEvent event) {
        receive(event);
        if (redis != null) {
            try { redis.convertAndSend(CHANNEL, mapper.writeValueAsString(event)); }
            catch (Exception failure) {
                log.warn("Domain fanout failed event={} failure={}", event.eventId(), failure.getClass().getSimpleName());
            }
        }
    }

    public void onRedisMessage(String raw) {
        try { receive(mapper.readValue(raw, DomainRealtimeEvent.class)); }
        catch (Exception invalid) { log.warn("Invalid domain fanout frame"); }
    }

    void receive(DomainRealtimeEvent event) {
        if (event == null || event.eventId() == null || event.scope() == null) return;
        synchronized (seen) {
            if (seen.putIfAbsent(event.eventId(), true) != null) return;
            if (seen.size() > 5000) seen.remove(seen.keySet().iterator().next());
        }
        for (Session session : sessions.values()) {
            // Community content never goes through group/author broadcast routing.
            // Recheck the canonical REST predicate immediately before each protected hint.
            boolean communityPost = "COMMUNITY_POST".equals(event.aggregateType());
            boolean communityPolicy = event.eventType() != null &&
                    (event.eventType().startsWith("FRIEND_") || (event.eventType().startsWith("GROUP_")
                        && !event.eventType().startsWith("GROUP_JOIN_") && !event.eventType().equals("GROUP_MEMBER_JOINED")
                        && (!event.scope().startsWith("user:") || event.scope().equals("user:"+session.userId)))
                    || (event.eventType().equals("COMMUNITY_POLICY_CHANGED")
                        && event.scope().equals("user:"+session.userId)))
                    && (event.payload()==null || !"RECIPIENT_ONLY".equals(event.payload().get("communityPolicyScope"))
                        || event.scope().equals("user:"+session.userId));
            if(communityPolicy)for(String scope:Set.copyOf(session.scopes))if(scope.startsWith("moderation:")) {
                if(!access.allowed(scope,session.userId)){session.scopes.remove(scope);send(session.socket,Map.of("type","SCOPE_REVOKED","scope",scope));}
                else send(session.socket,Map.of("type","SCOPE_RESYNC","scope",scope));
            }
            if (communityPost || communityPolicy) deliverCommunity(session,event,communityPost);
            if (communityPost) continue;
            boolean groupChange = event.eventType() != null && event.eventType().startsWith("GROUP_");
            for (String scope : Set.copyOf(session.scopes)) {
                boolean related = scope.equals(event.scope()) || (event.groupId() != null
                        && (scope.equals("group:" + event.groupId()) || event.groupId().equals(session.groups.get(scope))));
                if (!related) continue;
                if (!access.allowed(scope, session.userId)) {
                    session.scopes.remove(scope);
                    session.groups.remove(scope);
                    send(session.socket, Map.of("type", "SCOPE_REVOKED", "scope", scope));
                } else if (groupChange && event.groupId() != null) {
                    send(session.socket, Map.of("type", "SCOPE_RESYNC", "scope", scope));
                }
            }
            if (session.scopes.contains(event.scope()) || (event.groupId() != null
                    && session.scopes.contains("group:" + event.groupId()))) {
                if ("GROUP".equals(event.aggregateType()) && event.eventType().startsWith("GROUP_JOIN_")
                        && !access.canViewJoinRequests(event.aggregateId(), session.userId)) {
                    send(session.socket, Map.of("type", "SCOPE_RESYNC", "scope", event.scope()));
                } else if (!"MODERATION".equals(event.aggregateType()) || access.canViewModerationReport(event.aggregateId(),session.userId)) send(session.socket, event);
            }
        }
    }

    private DomainRealtimeEvent scoped(DomainRealtimeEvent source,String scope,String type,UUID id) {
        UUID eventId=UUID.nameUUIDFromBytes((source.eventId()+":"+scope).getBytes(java.nio.charset.StandardCharsets.UTF_8));
        return new DomainRealtimeEvent(eventId,"DOMAIN_CHANGED",type,
            type.equals("COMMUNITY_POLICY_CHANGED")?"USER":"COMMUNITY_POST",id,null,null,scope,source.occurredAt(),Map.of());
    }

    private void deliverCommunity(Session session,DomainRealtimeEvent event,boolean postEvent) {
        String feed="community:"+session.userId;
        boolean created="COMMUNITY_POST_CREATED".equals(event.eventType())||"COMMUNITY_RECRUITMENT_CREATED".equals(event.eventType());
        for(String scope:Set.copyOf(session.scopes)) {
            if(!(scope.startsWith("post:")||scope.startsWith("review:")) || (postEvent&&!scope.equals("post:"+event.aggregateId())&&!scope.equals("review:"+event.aggregateId()))) continue;
            if(!access.allowed(scope,session.userId)) {
                session.scopes.remove(scope);
                send(session.socket,Map.of("type","SCOPE_REVOKED","scope",scope));
            } else if(postEvent) {
                send(session.socket,scoped(event,scope,event.eventType(),event.aggregateId()));
            } else {
                send(session.socket,Map.of("type","SCOPE_RESYNC","scope",scope));
            }
        }
        if(!session.scopes.contains(feed))return;
        if(!access.allowed(feed,session.userId)) {
            session.scopes.remove(feed);send(session.socket,Map.of("type","SCOPE_REVOKED","scope",feed));return;
        }
        if(created) {
            if(access.allowed("post:"+event.aggregateId(),session.userId))send(session.socket,scoped(event,feed,event.eventType(),event.aggregateId()));
        } else if(!postEvent || "COMMUNITY_POST_UPDATED".equals(event.eventType()) || "COMMUNITY_POST_DELETED".equals(event.eventType())) {
            // No private author/post identity on global policy hints. Reaction/comment
            // events only reach subscribed visible resources, never invalidate the feed.
            send(session.socket,scoped(event,feed,"COMMUNITY_POLICY_CHANGED",session.userId));
        }
    }

    private void send(WebSocketSession socket, Object frame) {
        if (!socket.isOpen()) return;
        try {
            String raw = mapper.writeValueAsString(frame);
            synchronized (socket) { if (socket.isOpen()) socket.sendMessage(new TextMessage(raw)); }
        } catch (Exception failure) {
            log.warn("Domain socket delivery failed failure={}", failure.getClass().getSimpleName());
        }
    }

    private record Session(WebSocketSession socket, UUID userId, Set<String> scopes, Map<String, UUID> groups) { }
}
