package com.wedo.backend.community;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static com.wedo.backend.community.CommunityDtos.*;
import static com.wedo.backend.community.ModerationDtos.*;
import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.user.entity.*;
import com.wedo.backend.user.repository.UserRepository;
import com.wedo.backend.group.entity.*;
import com.wedo.backend.group.repository.*;
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
class ModerationIntegrationTest extends AbstractPostgresIntegrationTest {
    @MockitoBean com.google.firebase.FirebaseApp firebase;
    @MockitoBean com.google.firebase.messaging.FirebaseMessaging messaging;
 @Autowired com.wedo.backend.social.service.BlockService blocks;
 @Autowired ModerationService moderation; @Autowired CommunityService posts; @Autowired CommunityAccess access;
 @Autowired RecruitmentService recruitment; @Autowired UserRepository users; @Autowired GroupRepository groups;
 @Autowired GroupMembershipRepository members; @Autowired JdbcTemplate db; @Autowired RealtimeScopeAccess scopes;
 @Autowired DomainRealtimeCoordinator realtime; @Autowired PlatformTransactionManager transactions;
 @MockitoBean ObjectStorageService storage;
 @Autowired org.springframework.test.web.servlet.MockMvc http;
 @Autowired com.wedo.backend.security.jwt.JwtService jwt;
 UUID user(){UUID id=UUID.randomUUID();Instant n=Instant.now();users.save(new UserEntity(id,id+"@r7.test","u"+id.toString().substring(0,8),"R7 QA",UserStatus.ACTIVE,n,n));return id;}
 UUID moderator(){UUID u=user();db.update("INSERT INTO community_moderators(user_id) VALUES (?)",u);return u;}
 UUID group(UUID o){UUID id=UUID.randomUUID();Instant n=Instant.now();groups.save(new GroupEntity(id,"R7 private",null,null,GroupStatus.ACTIVE,o,n,n));members.save(new GroupMembershipEntity(UUID.randomUUID(),id,o,GroupRole.OWNER,GroupMembershipStatus.ACTIVE,n,null));db.update("INSERT INTO group_settings(group_id,join_policy) VALUES (?,'APPROVAL_REQUIRED')",id);return id;}
 Post post(UUID a){return posts.create(a,new Create(UUID.randomUUID(),"R7 safe fixture",Visibility.PUBLIC,null,List.of()));}
 Command command(Action a){return new Command(UUID.randomUUID(),a,"R7 QA decision");}
 @Test void globalGrantExplicitAndGroupOwnerCannotReviewPublicOrUser(){UUID o=user();group(o);UUID v=user();var p=post(o);UUID r=moderation.submit(v,Target.POST,p.id(),ReportReason.SPAM);assertFalse(moderation.capabilities(o).globalModerator());assertThrows(BusinessException.class,()->moderation.detail(r,o));assertThrows(BusinessException.class,()->moderation.queue(v,null,null,null,null));UUID m=moderator();assertEquals(r,moderation.detail(r,m).report().id());db.update("UPDATE community_moderators SET revoked_at=now() WHERE user_id=?",m);assertThrows(BusinessException.class,()->moderation.detail(r,m));assertFalse(scopes.allowed("moderation:"+m,m));}
 @Test void groupReviewIsolatedAndRoleLossDenied(){UUID o=user(),other=user(),v=user(),g=group(o);group(other);members.save(new GroupMembershipEntity(UUID.randomUUID(),g,v,GroupRole.MEMBER,GroupMembershipStatus.ACTIVE,Instant.now(),null));var p=posts.create(o,new Create(UUID.randomUUID(),"Private",Visibility.GROUP_ONLY,g,List.of()));UUID r=moderation.submit(v,Target.POST,p.id(),ReportReason.HARASSMENT);assertTrue(moderation.queue(o,null,null,null,null).items().stream().anyMatch(i->i.id().equals(r)));assertThrows(BusinessException.class,()->moderation.act(r,other,command(Action.REMOVE)));moderation.act(r,o,command(Action.REMOVE));assertFalse(access.canRead(p.id(),v));db.update("UPDATE group_memberships SET role='MEMBER' WHERE group_id=? AND user_id=?",g,o);assertThrows(BusinessException.class,()->moderation.detail(r,o));}
 @Test void reportNotRemovalAndHidePersonalReversible(){UUID a=user(),v=user(),m=moderator();var p=post(a);UUID r=moderation.submit(v,Target.POST,p.id(),ReportReason.SCAM);assertTrue(access.canRead(p.id(),v));assertEquals("SCAM",moderation.detail(r,m).report().reason());posts.hide(p.id(),v);assertFalse(access.canRead(p.id(),v));assertTrue(access.canRead(p.id(),a));assertTrue(posts.hidden(v,null).items().stream().anyMatch(h->h.id().equals(p.id())));posts.unhide(p.id(),v);assertTrue(access.canRead(p.id(),v));}
 @Test void hiddenListDoesNotLeakBlockedPosts(){UUID a=user(),v=user();var p=post(a);posts.hide(p.id(),v);db.update("INSERT INTO user_blocks(id,blocker_id,blocked_id) VALUES (?,?,?)",UUID.randomUUID(),a,v);assertTrue(posts.hidden(v,null).items().isEmpty());posts.unhide(p.id(),v);assertFalse(access.canRead(p.id(),v));}
 @Test void duplicateReportsAndCommandsIdempotent()throws Exception{UUID a=user(),v=user(),m=moderator();var p=post(a);try(var pool=java.util.concurrent.Executors.newFixedThreadPool(2)){var one=pool.submit(()->moderation.submit(v,Target.POST,p.id(),ReportReason.SPAM));var two=pool.submit(()->moderation.submit(v,Target.POST,p.id(),ReportReason.SPAM));assertEquals(one.get(),two.get());}UUID r=moderation.submit(v,Target.POST,p.id(),ReportReason.SPAM);Command c=command(Action.REMOVE);try(var pool=java.util.concurrent.Executors.newFixedThreadPool(2)){var one=pool.submit(()->moderation.act(r,m,c));var two=pool.submit(()->moderation.act(r,m,c));one.get();two.get();}assertEquals(1,moderation.detail(r,m).history().size());assertThrows(BusinessException.class,()->moderation.act(r,v,c));}
 @Test void restorePreservesPrivacyAndNeverRestoresDeletedPost(){UUID a=user(),v=user(),m=moderator();var p=posts.create(a,new Create(UUID.randomUUID(),"Friends",Visibility.FRIENDS,null,List.of()));UUID r=moderation.submit(a,Target.POST,p.id(),ReportReason.SPAM);moderation.act(r,m,command(Action.REMOVE));assertFalse(access.canRead(p.id(),a));moderation.act(r,m,command(Action.RESTORE));assertTrue(access.canRead(p.id(),a));assertFalse(access.canRead(p.id(),v));posts.delete(p.id(),a);assertThrows(BusinessException.class,()->moderation.act(r,m,command(Action.RESTORE)));}
 @Test void commentRemovalRestorationAndReplayGuard(){UUID a=user(),v=user(),m=moderator();var p=post(a);UUID c=UUID.randomUUID();posts.addComment(p.id(),v,new AddComment(c,"Evidence"));UUID r=moderation.submit(a,Target.COMMENT,c,ReportReason.INAPPROPRIATE_CONTENT);moderation.act(r,m,command(Action.REMOVE));assertEquals(0,posts.get(p.id(),a).commentCount());assertTrue(posts.comments(p.id(),a,null).items().isEmpty());assertThrows(BusinessException.class,()->posts.addComment(p.id(),v,new AddComment(c,"Replay")));moderation.act(r,m,command(Action.RESTORE));assertEquals(1,posts.get(p.id(),a).commentCount());}
 @Test void userReportCannotBanAndHasNoOrdinaryReviewAccess(){UUID a=user(),v=user(),m=moderator();UUID r=moderation.submit(v,Target.USER,a,ReportReason.HARASSMENT);assertThrows(BusinessException.class,()->moderation.act(r,m,command(Action.REMOVE)));moderation.act(r,m,command(Action.RESOLVE));assertEquals("ACTIVE",db.queryForObject("SELECT status FROM users WHERE id=?",String.class,a));assertThrows(BusinessException.class,()->moderation.detail(r,v));}
 @Test void queueCursorFiltersAndDismissRetainsContent(){UUID a=user(),v=user(),m=moderator();for(int i=0;i<23;i++)moderation.submit(v,Target.POST,post(a).id(),ReportReason.OTHER);var first=moderation.queue(m,"OPEN","OTHER",Target.POST,null);assertTrue(first.hasMore());var second=moderation.queue(m,"OPEN","OTHER",Target.POST,first.nextBefore());assertTrue(Collections.disjoint(first.items().stream().map(Item::id).toList(),second.items().stream().map(Item::id).toList()));var item=first.items().getFirst();moderation.act(item.id(),m,command(Action.DISMISS));assertTrue(access.canRead(item.postId(),v));}
 @Test void removedRecruitmentCannotAdmitPendingRequest(){UUID a=user(),v=user(),m=moderator(),g=group(a);var p=recruitment.create(a,new RecruitmentDtos.Create(UUID.randomUUID(),g,null,"R7 recruit",Visibility.PUBLIC,2,"",List.of(),null,null,List.of()));var pending=recruitment.request(p.id(),v);UUID r=moderation.submit(v,Target.POST,p.id(),ReportReason.SPAM);moderation.act(r,m,command(Action.REMOVE));assertThrows(BusinessException.class,()->recruitment.request(p.id(),user()));assertThrows(BusinessException.class,()->recruitment.resolve(p.id(),pending.requestId(),a,true));assertEquals(1,db.queryForObject("SELECT count(*) FROM group_memberships WHERE group_id=? AND status='ACTIVE'",Integer.class,g));}
 @Test void rollbackNoDeliveryAndAfterCommitRevokesScope()throws Exception{UUID a=user(),v=user(),m=moderator();var p=post(a);UUID r=moderation.submit(v,Target.POST,p.id(),ReportReason.SPAM);var socket=mock(org.springframework.web.socket.WebSocketSession.class);when(socket.getId()).thenReturn("r7-"+v);when(socket.isOpen()).thenReturn(true);realtime.register(socket,v);realtime.command(socket,"{\"type\":\"SUBSCRIBE_SCOPE\",\"scope\":\"post:"+p.id()+"\"}");clearInvocations(socket);new TransactionTemplate(transactions).executeWithoutResult(tx->{moderation.act(r,m,command(Action.REMOVE));tx.setRollbackOnly();});assertTrue(access.canRead(p.id(),v));verify(socket,never()).sendMessage(any());moderation.act(r,m,command(Action.REMOVE));verify(socket,timeout(5000).atLeastOnce()).sendMessage(argThat(msg->msg.getPayload().toString().contains("SCOPE_REVOKED")));realtime.unregister(socket);}
 @Test void httpQueueRequiresAuthenticationAndExplicitReviewPermission()throws Exception{
  UUID v=user(),m=moderator();
  http.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get("/api/v1/moderation/reports")).andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.status().isUnauthorized());
  http.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get("/api/v1/moderation/reports").header("Authorization","Bearer "+jwt.generateAccessToken(v))).andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.status().isForbidden());
  http.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get("/api/v1/moderation/reports").header("Authorization","Bearer "+jwt.generateAccessToken(m))).andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.status().isOk()).andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.items[0].reporterId").doesNotExist());
 }
 @Test void moderatedMediaCannotIssueNewSignedUrlsAndExistingUrlsAreSixtySeconds(){
  UUID a=user(),v=user(),m=moderator();
  var refs=org.springframework.test.util.ReflectionTestUtils.getField(posts,"refs");
  String key=((com.wedo.backend.media.service.MediaReferenceService)refs).newKey(com.wedo.backend.media.dto.UploadCategory.COMMUNITY_IMAGE,a,a);
  when(storage.head(key)).thenReturn(new ObjectStorageService.ObjectMetadata("image/png",42,Map.of("declared-size","42","original-file-name",Base64.getUrlEncoder().withoutPadding().encodeToString("qa.png".getBytes()))));
  when(storage.presignGet(eq(key),any())).thenReturn(new ObjectStorageService.PresignedObject("https://private.test/image",Instant.now().plusSeconds(60),Map.of()));
  var p=posts.create(a,new Create(UUID.randomUUID(),"Media",Visibility.PUBLIC,null,List.of(key)));UUID media=p.media().getFirst().id();
  posts.mediaAccess(media,v);verify(storage).presignGet(key,Duration.ofSeconds(60));UUID r=moderation.submit(v,Target.POST,p.id(),ReportReason.SPAM);moderation.act(r,m,command(Action.REMOVE));
  clearInvocations(storage);assertThrows(BusinessException.class,()->posts.mediaAccess(media,v));verify(storage,never()).presignGet(any(),any());
  assertThrows(BusinessException.class,()->moderation.evidenceMedia(r,media,v));assertThrows(BusinessException.class,()->moderation.evidenceMedia(r,UUID.randomUUID(),m));assertNotNull(moderation.evidenceMedia(r,media,m));
  db.update("UPDATE community_moderators SET revoked_at=now() WHERE user_id=?",m);assertThrows(BusinessException.class,()->moderation.evidenceMedia(r,media,m));db.update("UPDATE community_moderators SET revoked_at=NULL WHERE user_id=?",m);
  moderation.act(r,m,command(Action.RESTORE));assertNotNull(posts.mediaAccess(media,v));
 }

 private org.springframework.web.socket.WebSocketSession socket(UUID viewer,String name,String... subscriptions)throws Exception {
  var socket=mock(org.springframework.web.socket.WebSocketSession.class);when(socket.getId()).thenReturn(name);when(socket.isOpen()).thenReturn(true);realtime.register(socket,viewer);
  for(String scope:subscriptions)realtime.command(socket,"{\"type\":\"SUBSCRIBE_SCOPE\",\"scope\":\""+scope+"\"}");
  clearInvocations(socket);return socket;
 }
 @Test void nonFriendBlockAndUnblockDoNotRefreshUnrelatedViewerOrModerator()throws Exception{
  UUID a=user(),b=user(),owner=moderator();var p=post(b);awaitDelivery();
  var peer=socket(a,"r7-peer-"+a,"community:"+a,"user:"+a,"post:"+p.id());
  var unrelated=socket(owner,"r7-owner-"+owner,"community:"+owner,"moderation:"+owner,"post:"+p.id());
  try{
   blocks.blockUser(a,b);awaitDelivery();assertFalse(access.canRead(p.id(),a));assertTrue(access.canRead(p.id(),owner));
   verify(unrelated,never()).sendMessage(any());verify(peer,atLeastOnce()).sendMessage(argThat(m->m.getPayload().toString().contains("SCOPE_REVOKED")));
   clearInvocations(peer,unrelated);blocks.unblockUser(a,b);awaitDelivery();assertTrue(access.canRead(p.id(),a));
   verify(unrelated,never()).sendMessage(any());verify(peer,atLeastOnce()).sendMessage(argThat(m->m.getPayload().toString().contains("COMMUNITY_POLICY_CHANGED")));
  }finally{realtime.unregister(peer);realtime.unregister(unrelated);}
 }
 @Test void friendBlockStillRevokesThirdPartyFofAccess()throws Exception{
  UUID a=user(),b=user(),third=user();
  for(UUID v:List.of(b,third))db.update("INSERT INTO friendships(id,user_id_1,user_id_2) VALUES (?,LEAST(?::uuid,?::uuid),GREATEST(?::uuid,?::uuid))",UUID.randomUUID(),a,v,a,v);
  var p=posts.create(b,new Create(UUID.randomUUID(),"FOF",Visibility.FRIENDS_OF_FRIENDS,null,List.of()));awaitDelivery();assertTrue(access.canRead(p.id(),third));
  var socket=socket(third,"r7-fof-"+third,"community:"+third,"post:"+p.id());
  try{blocks.blockUser(a,b);awaitDelivery();assertFalse(access.canRead(p.id(),third));verify(socket,atLeastOnce()).sendMessage(argThat(m->m.getPayload().toString().contains("SCOPE_REVOKED")));}
  finally{realtime.unregister(socket);}
 }

}
