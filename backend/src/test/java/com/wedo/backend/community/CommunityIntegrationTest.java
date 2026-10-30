package com.wedo.backend.community;

import static com.wedo.backend.community.CommunityDtos.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.user.entity.*;
import com.wedo.backend.user.repository.UserRepository;
import com.wedo.backend.group.entity.*;
import com.wedo.backend.group.repository.*;
import com.wedo.backend.media.service.*;
import com.wedo.backend.media.dto.*;
import com.wedo.backend.media.storage.ObjectStorageService;
import com.wedo.backend.realtime.*;
import java.time.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

@org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
class CommunityIntegrationTest extends AbstractPostgresIntegrationTest {
    @MockitoBean com.google.firebase.FirebaseApp firebase;
    @MockitoBean com.google.firebase.messaging.FirebaseMessaging messaging;
    @Autowired CommunityService service;
    @Autowired CommunityAccess access;
    @Autowired RealtimeScopeAccess scopes;
    @Autowired UserRepository users;
    @Autowired GroupRepository groups;
    @Autowired GroupMembershipRepository members;
    @Autowired JdbcTemplate db;
    @Autowired MediaReferenceService refs;
    @Autowired UploadService uploads;
    @Autowired DomainRealtimeCoordinator realtime;
    @Autowired PlatformTransactionManager transactions;
    @Autowired org.springframework.test.web.servlet.MockMvc http;
    @Autowired com.wedo.backend.security.jwt.JwtService jwt;
    @MockitoBean ObjectStorageService storage;
    UUID user() {
        UUID id=UUID.randomUUID();Instant now=Instant.now();
        users.save(new UserEntity(id,id+"@r5.test","u"+id.toString().substring(0,8),"QA Community",UserStatus.ACTIVE,now,now));return id;
    }
    void friend(UUID a,UUID b) {
        db.update("INSERT INTO friendships(id,user_id_1,user_id_2) VALUES (?,LEAST(?::uuid,?::uuid),GREATEST(?::uuid,?::uuid))",UUID.randomUUID(),a,b,a,b);
    }
    void block(UUID a,UUID b) { db.update("INSERT INTO user_blocks(id,blocker_id,blocked_id) VALUES (?,?,?)",UUID.randomUUID(),a,b); }
    UUID group(UUID owner,UUID member) {
        UUID g=UUID.randomUUID();Instant n=Instant.now();groups.save(new GroupEntity(g,"R5 isolated",null,null,GroupStatus.ACTIVE,owner,n,n));
        members.save(new GroupMembershipEntity(UUID.randomUUID(),g,owner,GroupRole.OWNER,GroupMembershipStatus.ACTIVE,n,null));
        members.save(new GroupMembershipEntity(UUID.randomUUID(),g,member,GroupRole.MEMBER,GroupMembershipStatus.ACTIVE,n,null));return g;
    }
    Post post(UUID author,Visibility visibility) { return service.create(author,new Create(UUID.randomUUID(),"R5 QA",visibility,null,List.of())); }
    String key(UUID author) {
        String key=refs.newKey(UploadCategory.COMMUNITY_IMAGE,author,author);
        when(storage.head(key)).thenReturn(new ObjectStorageService.ObjectMetadata("image/png",42,Map.of("declared-size","42","original-file-name",Base64.getUrlEncoder().withoutPadding().encodeToString("qa.png".getBytes()))));
        when(storage.presignGet(eq(key),any())).thenReturn(new ObjectStorageService.PresignedObject("https://private.test/image",Instant.now().plusSeconds(60),Map.of()));return key;
    }
    @Test void visibilityMatrixUsesConfirmedGraphAndBlockOverrides() {
        UUID a=user(),b=user(),c=user(),x=user();friend(a,b);friend(b,c);
        Post pub=post(a,Visibility.PUBLIC),friends=post(a,Visibility.FRIENDS),fof=post(a,Visibility.FRIENDS_OF_FRIENDS);
        assertTrue(access.canRead(pub.id(),x));assertFalse(access.canRead(friends.id(),c));assertTrue(access.canRead(friends.id(),b));assertTrue(access.canRead(fof.id(),c));assertFalse(access.canRead(fof.id(),x));
        block(c,b);assertFalse(access.canRead(fof.id(),c));block(b,a);
        assertFalse(access.canRead(pub.id(),b));assertFalse(access.canRead(friends.id(),b));assertThrows(BusinessException.class,()->service.react(pub.id(),b,"❤️"));
    }
    @Test void feedsAndProfileFilterBeforePagination() {
        UUID a=user(),v=user(),x=user();friend(a,v);
        var publicPost=post(a,Visibility.PUBLIC);var friendPost=post(a,Visibility.FRIENDS);var excluded=post(x,Visibility.FRIENDS);
        var own=post(v,Visibility.FRIENDS);
        var mixed=service.feed(v,Feed.FOR_YOU,null,null).items();
        assertTrue(mixed.stream().anyMatch(p->p.id().equals(friendPost.id())));
        assertTrue(mixed.stream().anyMatch(p->p.id().equals(own.id())));
        assertFalse(mixed.stream().anyMatch(p->p.id().equals(excluded.id())));
        assertEquals(2,service.feed(v,Feed.PROFILE,a,null).items().size());
        assertTrue(service.feed(v,Feed.FRIENDS,null,null).items().stream().allMatch(p->p.author().id().equals(a)));
        block(v,a);assertFalse(service.feed(v,Feed.FOR_YOU,null,null).items().stream().anyMatch(p->p.id().equals(publicPost.id())));assertTrue(service.feed(v,Feed.PROFILE,a,null).items().isEmpty());
    }
    @Test void forYouMixesAllEligibleModesWithoutLeakingFriendOrGroupContent() {
        UUID a=user(),bridge=user(),v=user(),outsider=user();friend(a,bridge);friend(bridge,v);UUID g=group(a,v);
        var pub=post(a,Visibility.PUBLIC);var fof=post(a,Visibility.FRIENDS_OF_FRIENDS);var privateFriend=post(a,Visibility.FRIENDS);
        var groupPost=service.create(a,new Create(UUID.randomUUID(),"Group eligible",Visibility.GROUP_ONLY,g,List.of()));
        var eligible=service.feed(v,Feed.FOR_YOU,null,null).items().stream().map(Post::id).toList();
        assertTrue(eligible.containsAll(List.of(pub.id(),fof.id(),groupPost.id())));assertFalse(eligible.contains(privateFriend.id()));
        var other=service.feed(outsider,Feed.FOR_YOU,null,null).items().stream().map(Post::id).toList();
        assertTrue(other.contains(pub.id()));assertFalse(other.contains(fof.id()));assertFalse(other.contains(groupPost.id()));
        block(v,a);assertFalse(service.feed(v,Feed.FOR_YOU,null,null).items().stream().anyMatch(p->p.author().id().equals(a)));
    }
    @Test void groupOwnershipMembershipBanAndModeration() {
        UUID o=user(),m=user(),x=user();UUID g=group(o,m);
        Post p=service.create(m,new Create(UUID.randomUUID(),"Group",Visibility.GROUP_ONLY,g,List.of()));
        assertTrue(access.canRead(p.id(),o));assertFalse(access.canRead(p.id(),x));
        assertThrows(BusinessException.class,()->service.create(x,new Create(UUID.randomUUID(),"Forged",Visibility.GROUP_ONLY,g,List.of())));
        assertThrows(BusinessException.class,()->service.edit(p.id(),o,new Edit("Public leak",Visibility.PUBLIC,null)));
        db.update("INSERT INTO group_bans(id,group_id,user_id,banned_by) VALUES (?,?,?,?)",UUID.randomUUID(),g,m,o);
        assertFalse(access.canRead(p.id(),m));service.delete(p.id(),o);assertFalse(access.canRead(p.id(),o));
    }
    @Test void mediaOwnershipAndEveryReadFollowVisibility() {
        UUID a=user(),v=user();String k=key(a);
        Post p=service.create(a,new Create(UUID.randomUUID(),"Photo",Visibility.FRIENDS,null,List.of(k)));
        UUID media=p.media().getFirst().id();assertThrows(BusinessException.class,()->service.mediaAccess(media,v));
        friend(a,v);assertNotNull(service.mediaAccess(media,v).url());block(a,v);assertThrows(BusinessException.class,()->service.mediaAccess(media,v));
        assertThrows(BusinessException.class,()->service.create(v,new Create(UUID.randomUUID(),"Stolen",Visibility.PUBLIC,null,List.of(k))));
        assertThrows(BusinessException.class,()->uploads.presign(v,new PresignUploadRequest(UploadCategory.COMMUNITY_IMAGE,"qa.png","image/png",42,a.toString())));
    }
    @Test void createCommentsAndReactionsAreIdempotent()throws Exception {
        UUID a=user(),v=user(),id=UUID.randomUUID();var req=new Create(id,"Retry",Visibility.PUBLIC,null,List.of(key(a)));
        try(var pool=java.util.concurrent.Executors.newFixedThreadPool(2)) {
            var one=pool.submit(()->service.create(a,req));var two=pool.submit(()->service.create(a,req));assertEquals(id,one.get().id());assertEquals(id,two.get().id());
        }
        service.react(id,v,"❤️");service.react(id,v,"❤️");service.react(id,v,"👍");assertEquals(1,service.get(id,a).reactionCount());service.react(id,v,null);assertEquals(0,service.get(id,a).reactionCount());
        UUID comment=UUID.randomUUID();service.addComment(id,v,new AddComment(comment,"Hello"));service.addComment(id,v,new AddComment(comment,"Hello"));assertEquals(1,service.get(id,a).commentCount());
        service.deleteComment(id,comment,v);assertEquals(0,service.get(id,a).commentCount());
    }
    @Test void blockedCommentersAndReactionsAreNotExposed() {
        UUID a=user(),v=user(),b=user();Post p=post(a,Visibility.PUBLIC);
        service.addComment(p.id(),b,new AddComment(UUID.randomUUID(),"Blocked commenter"));service.react(p.id(),b,"❤️");block(v,b);
        assertEquals(0,service.get(p.id(),v).commentCount());assertEquals(0,service.get(p.id(),v).reactionCount());assertTrue(service.comments(p.id(),v,null).items().isEmpty());
    }
    @Test void hideAndReportArePersonalAndDoNotRemoveOthersContent() {
        UUID a=user(),v=user(),x=user();Post p=post(a,Visibility.PUBLIC);
        service.report(p.id(),v,ReportReason.SPAM);service.report(p.id(),v,ReportReason.OTHER);
        assertEquals(1,db.queryForObject("SELECT count(*) FROM community_reports WHERE post_id=?",Integer.class,p.id()));
        assertTrue(access.canRead(p.id(),x));service.hide(p.id(),v);service.hide(p.id(),v);assertFalse(access.canRead(p.id(),v));assertTrue(access.canRead(p.id(),x));
    }
    @Test void editDeleteAndPrivateCursorAreSafe() {
        UUID a=user(),v=user();Post p=post(a,Visibility.PUBLIC),privatePost=post(a,Visibility.FRIENDS);
        assertThrows(BusinessException.class,()->service.edit(p.id(),v,new Edit("Forged",Visibility.PUBLIC,null)));
        assertThrows(BusinessException.class,()->service.feed(v,Feed.FOR_YOU,null,privatePost.id()));
        service.edit(p.id(),a,new Edit("Narrow",Visibility.FRIENDS,null));assertFalse(access.canRead(p.id(),v));service.delete(p.id(),a);assertFalse(access.canRead(p.id(),a));verify(storage,never()).delete(any());
    }
    @Test void stableFeedAndCommentCursorsHaveNoDuplicates() {
        UUID a=user(),v=user();for(int i=0;i<23;i++)post(a,Visibility.PUBLIC);
        var first=service.feed(v,Feed.PROFILE,a,null);assertEquals(20,first.items().size());post(a,Visibility.PUBLIC);
        var older=service.feed(v,Feed.PROFILE,a,first.nextBefore());assertEquals(3,older.items().size());
        Set<UUID> ids=new HashSet<>();first.items().forEach(p->assertTrue(ids.add(p.id())));older.items().forEach(p->assertTrue(ids.add(p.id())));
        UUID id=first.items().getFirst().id();for(int i=0;i<23;i++)service.addComment(id,v,new AddComment(UUID.randomUUID(),"Comment "+i));
        var comments=service.comments(id,v,null);assertEquals(20,comments.items().size());assertEquals(3,service.comments(id,v,comments.nextBefore()).items().size());
    }
    @Test void rollbackAndAfterCommitUseExistingAuthorizedTransport()throws Exception {
        UUID a=user(),v=user();var socket=mock(org.springframework.web.socket.WebSocketSession.class);when(socket.getId()).thenReturn("r5-"+v);when(socket.isOpen()).thenReturn(true);
        realtime.register(socket,v);assertTrue(realtime.command(socket,"{\"type\":\"SUBSCRIBE_SCOPE\",\"scope\":\"community:"+v+"\"}"));clearInvocations(socket);
        UUID rolled=UUID.randomUUID();new TransactionTemplate(transactions).executeWithoutResult(tx->{service.create(a,new Create(rolled,"Rollback",Visibility.PUBLIC,null,List.of()));tx.setRollbackOnly();});
        assertFalse(access.canRead(rolled,v));verify(socket,never()).sendMessage(any());
        Post p=post(a,Visibility.FRIENDS);verify(socket,never()).sendMessage(any());
        Post pub=post(a,Visibility.PUBLIC);verify(socket,timeout(5000).atLeastOnce()).sendMessage(argThat(m->m.getPayload().toString().contains(pub.id().toString())));
        assertFalse(scopes.allowed("post:"+p.id(),v));assertFalse(scopes.allowed("community:"+a,v));realtime.unregister(socket);
    }
    @Test void secondClientConvergesAfterAuthorEditAndDeletion()throws Exception {
        UUID a=user(),v=user();Post p=post(a,Visibility.PUBLIC);
        var socket=mock(org.springframework.web.socket.WebSocketSession.class);when(socket.getId()).thenReturn("r5-edit-"+v);when(socket.isOpen()).thenReturn(true);
        realtime.register(socket,v);realtime.command(socket,"{\"type\":\"SUBSCRIBE_SCOPE\",\"scope\":\"post:"+p.id()+"\"}");clearInvocations(socket);
        assertThrows(BusinessException.class,()->service.delete(p.id(),v));
        service.edit(p.id(),a,new Edit("Edited authoritative caption",Visibility.PUBLIC,null));
        verify(socket,timeout(5000).atLeastOnce()).sendMessage(argThat(m->m.getPayload().toString().contains("COMMUNITY_POST_UPDATED")));
        assertEquals("Edited authoritative caption",service.get(p.id(),v).caption());clearInvocations(socket);
        service.delete(p.id(),a);verify(socket,timeout(5000).atLeastOnce()).sendMessage(argThat(m->m.getPayload().toString().contains("SCOPE_REVOKED")));
        assertThrows(BusinessException.class,()->service.get(p.id(),v));realtime.unregister(socket);
    }
    @Test void restRequiresAuthAndValidatesRequestWithoutLeakingKeys()throws Exception {
        UUID a=user();String token="Bearer "+jwt.generateAccessToken(a);
        http.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get("/api/v1/community/posts")).andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.status().isUnauthorized());
        http.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post("/api/v1/community/posts").header("Authorization",token).contentType("application/json").content("{\"caption\":\"invalid\"}")).andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.status().isBadRequest());
        Post p=service.create(a,new Create(UUID.randomUUID(),"Photo",Visibility.PUBLIC,null,List.of(key(a))));
        http.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get("/api/v1/community/posts/"+p.id()).header("Authorization",token)).andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.status().isOk()).andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.media[0].storageKey").doesNotExist());
    }
    @Test void rankingCursorHttpIsOpaqueValidatedAndRefreshIsBounded()throws Exception {
        UUID a=user();String token="Bearer "+jwt.generateAccessToken(a);
        for(String invalid:List.of("not-a-cursor",UUID.randomUUID().toString(),"1-1-1-1-1"))
          http.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get("/api/v1/community/posts").param("before",invalid).header("Authorization",token))
            .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.status().isBadRequest());
        http.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post("/api/v1/community/posts/refresh").header("Authorization",token).contentType("application/json").content("{\"feed\":\"FOR_YOU\",\"ids\":[]}"))
          .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.status().isOk());
        http.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post("/api/v1/community/posts/refresh").header("Authorization",token).contentType("application/json").content("{\"feed\":\"FOR_YOU\",\"ids\":[null]}"))
          .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.status().isBadRequest());
        http.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get("/api/v1/community/posts").header("Authorization",token))
          .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.status().isOk())
          .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.items[0].score").doesNotExist())
          .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.items[0].media[0].storageKey").doesNotExist());
    }

}
