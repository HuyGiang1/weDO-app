package com.wedo.backend.realtime;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.wedo.backend.common.event.PostCommitDelivery;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.web.socket.*;

class CommunityRealtimeTest {
    final ObjectMapper mapper=new ObjectMapper().findAndRegisterModules();
    final RealtimeScopeAccess access=mock(RealtimeScopeAccess.class);
    final DomainRealtimeCoordinator coordinator=new DomainRealtimeCoordinator(mapper,access,mock(PostCommitDelivery.class),null);
    final UUID viewer=UUID.randomUUID(),post=UUID.randomUUID(),author=UUID.randomUUID();
    WebSocketSession socket() {
        var s=mock(WebSocketSession.class);when(s.getId()).thenReturn("r5");when(s.isOpen()).thenReturn(true);coordinator.register(s,viewer);return s;
    }
    void subscribe(WebSocketSession s,String scope){when(access.allowed(scope,viewer)).thenReturn(true);coordinator.command(s,"{\"type\":\"SUBSCRIBE_SCOPE\",\"scope\":\""+scope+"\"}");clearInvocations(s);}
    DomainRealtimeEvent event(String type){return DomainRealtimeEvent.changed(type,"COMMUNITY_POST",post,null,null,"community:"+author);}
    @Test void privateNewPostNeverLeaksIdToFeed()throws Exception {
        var s=socket();subscribe(s,"community:"+viewer);coordinator.receive(event("COMMUNITY_POST_CREATED"));verify(s,never()).sendMessage(any());
    }
    @Test void authorizedNewPostRewritesOnlyViewerScopeAndDeduplicates()throws Exception {
        var s=socket();subscribe(s,"community:"+viewer);when(access.allowed("post:"+post,viewer)).thenReturn(true);
        var event=event("COMMUNITY_POST_CREATED");coordinator.receive(event);coordinator.receive(event);
        var frame=ArgumentCaptor.forClass(TextMessage.class);verify(s).sendMessage(frame.capture());
        var j=mapper.readTree(frame.getValue().getPayload());assertEquals("community:"+viewer,j.path("scope").asText());assertTrue(j.path("actorId").isNull());
    }
    @Test void reactionTargetsVisiblePostOnlyAndRevocationRechecksPermission()throws Exception {
        var s=socket();subscribe(s,"community:"+viewer);subscribe(s,"post:"+post);
        coordinator.receive(event("COMMUNITY_REACTION_CHANGED"));
        var frames=ArgumentCaptor.forClass(TextMessage.class);verify(s).sendMessage(frames.capture());assertEquals("post:"+post,mapper.readTree(frames.getValue().getPayload()).path("scope").asText());
        when(access.allowed("post:"+post,viewer)).thenReturn(false);clearInvocations(s);
        coordinator.receive(event("COMMUNITY_COMMENT_CHANGED"));verify(s).sendMessage(frames.capture());assertTrue(frames.getValue().getPayload().contains("SCOPE_REVOKED"));assertFalse(frames.getValue().getPayload().contains("DOMAIN_CHANGED"));
    }
    @Test void recruitmentJoinDoesNotReloadFeedAndReviewScopeIsRoleGuarded()throws Exception {
        var s=socket();subscribe(s,"community:"+viewer);subscribe(s,"post:"+post);subscribe(s,"review:"+post);
        coordinator.receive(DomainRealtimeEvent.changed("GROUP_JOIN_REQUESTED","GROUP",UUID.randomUUID(),null,null,"user:"+viewer));
        verify(s,never()).sendMessage(any());
        coordinator.receive(event("COMMUNITY_RECRUITMENT_CHANGED"));
        var frames=ArgumentCaptor.forClass(TextMessage.class);verify(s,times(2)).sendMessage(frames.capture());
        assertTrue(frames.getAllValues().stream().noneMatch(f->f.getPayload().contains("community:"+viewer)));
    }
    @Test void roleLossRevokesReviewEvenWhenPublicPostRemainsReadable()throws Exception {
        var s=socket();subscribe(s,"post:"+post);subscribe(s,"review:"+post);when(access.allowed("review:"+post,viewer)).thenReturn(false);
        coordinator.receive(DomainRealtimeEvent.changed("GROUP_UPDATED","GROUP",UUID.randomUUID(),UUID.randomUUID(),null,"group:"+UUID.randomUUID()));
        var frames=ArgumentCaptor.forClass(TextMessage.class);verify(s,times(2)).sendMessage(frames.capture());
        assertTrue(frames.getAllValues().stream().anyMatch(f->f.getPayload().contains("SCOPE_REVOKED")&&f.getPayload().contains("review:"+post)));
    }
    @Test void graphChangeRevokesVisiblePrivatePostAndSendsActorFreePolicyHint()throws Exception {
        var s=socket();subscribe(s,"community:"+viewer);subscribe(s,"post:"+post);when(access.allowed("post:"+post,viewer)).thenReturn(false);
        coordinator.receive(DomainRealtimeEvent.changed("FRIEND_REMOVED","USER",author,null,null,"user:"+author));
        var frames=ArgumentCaptor.forClass(TextMessage.class);verify(s,times(2)).sendMessage(frames.capture());
        assertTrue(frames.getAllValues().stream().anyMatch(f->f.getPayload().contains("SCOPE_REVOKED")));
        var policy=frames.getAllValues().stream().filter(f->f.getPayload().contains("COMMUNITY_POLICY_CHANGED")).findFirst().orElseThrow();
        assertFalse(policy.getPayload().contains(author.toString()));assertFalse(policy.getPayload().contains(post.toString()));
    }
    @Test void personalHidePolicyDoesNotResyncAnotherUsersFeedOrModeratorQueue()throws Exception {
        var s=socket();subscribe(s,"community:"+viewer);subscribe(s,"post:"+post);subscribe(s,"moderation:"+viewer);
        coordinator.receive(DomainRealtimeEvent.changed("COMMUNITY_POLICY_CHANGED","USER",author,null,null,"user:"+author));
        verify(s,never()).sendMessage(any());
    }

}
