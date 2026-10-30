package com.wedo.backend.realtime;
import static org.junit.jupiter.api.Assertions.*;
import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.user.entity.*;
import com.wedo.backend.user.repository.UserRepository;
import com.wedo.backend.group.entity.*;
import com.wedo.backend.group.repository.*;
import java.time.Instant;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
class RealtimeReadModelFanoutIntegrationTest extends AbstractPostgresIntegrationTest {
 @Autowired UserRepository users; @Autowired GroupRepository groups; @Autowired GroupMembershipRepository memberships;
 @Autowired DomainRealtimeCoordinator coordinator; @Autowired PlatformTransactionManager tx;
 @Autowired ApplicationEventPublisher events; @Autowired JdbcTemplate jdbc;
 @Autowired(required=false) RealtimeReadModelFanout fanout;
 @MockitoBean com.google.firebase.FirebaseApp firebaseAdminApp;
 @MockitoBean com.google.firebase.messaging.FirebaseMessaging firebaseMessaging;
 UUID user(){UUID id=UUID.randomUUID();Instant n=Instant.now();users.save(new UserEntity(id,id+"@r2.test","u"+id.toString().substring(0,8),"R2 QA",UserStatus.ACTIVE,n,n));return id;}
 record Fixture(UUID group,UUID owner,UUID member,UUID outsider){}
 Fixture fixture(){Instant n=Instant.now();UUID o=user(),m=user(),x=user(),g=UUID.randomUUID();groups.save(new GroupEntity(g,"R2 fanout",null,null,GroupStatus.ACTIVE,o,n,n));for(UUID u:List.of(o,m))memberships.save(new GroupMembershipEntity(UUID.randomUUID(),g,u,u.equals(o)?GroupRole.OWNER:GroupRole.MEMBER,GroupMembershipStatus.ACTIVE,n,null));return new Fixture(g,o,m,x);}
 DomainRealtimeEvent event(Fixture f,String type){return DomainRealtimeEvent.changed(type,"GROUP",f.group(),f.group(),f.owner(),"group:"+f.group());}
 void commit(DomainRealtimeEvent e){new TransactionTemplate(tx).executeWithoutResult(s->events.publishEvent(e));awaitDelivery();}
 @Test void aggregateHintsEnabledByDefaultOnlyAfterCommitAndForCurrentMembers() throws Exception {
  assertNotNull(fanout,"R2 aggregate consumers must be enabled by default");Fixture f=fixture();
  try(var peer=new RealtimeProbe(coordinator,f.member(),"user:self");var outside=new RealtimeProbe(coordinator,f.outsider(),"user:self")){
   new TransactionTemplate(tx).executeWithoutResult(s->{events.publishEvent(event(f,"EXPENSE_CREATED"));assertTrue(peer.frames.isEmpty());});awaitDelivery();
   String hint=peer.await("HOME_CHANGED");assertFalse(hint.contains(f.group().toString()));assertFalse(hint.contains(f.owner().toString()));assertTrue(outside.frames.isEmpty());assertTrue(peer.frames.stream().noneMatch(s->s.contains("CALENDAR_CHANGED")));
  }
 }
 @Test void rollbackPublishesNoPersonalHint() throws Exception {
  Fixture f=fixture();try(var peer=new RealtimeProbe(coordinator,f.member(),"user:self")){
   new TransactionTemplate(tx).executeWithoutResult(s->{events.publishEvent(event(f,"GROUP_UPDATED"));s.setRollbackOnly();});awaitDelivery();assertTrue(peer.frames.isEmpty());
  }
 }
 @Test void dependenciesAndDuplicateEventsDoNotRefreshUnrelatedReadModels() throws Exception {
  Fixture f=fixture();try(var peer=new RealtimeProbe(coordinator,f.member(),"user:self")){
   commit(event(f,"DISCUSSION_COMMENT_CREATED"));commit(event(f,"ACTIVITY_STOP_CHECKIN_CHANGED"));commit(event(f,"FUND_CONTRIBUTION_CREATED"));assertTrue(peer.frames.isEmpty());
   var e=event(f,"TASK_STATUS_CHANGED");commit(e);commit(e);assertEquals(1,peer.frames.stream().filter(s->s.contains("HOME_CHANGED")).count());assertTrue(peer.frames.stream().noneMatch(s->s.contains("CALENDAR_CHANGED")));
   peer.frames.clear();commit(event(f,"GROUP_UPDATED"));peer.await("HOME_CHANGED");peer.await("CALENDAR_CHANGED");peer.await("GROUP_LIST_CHANGED");
  }
 }
 @Test void membershipIsRecheckedBeforeReadModelRecipientsAreSelected() throws Exception {
  Fixture f=fixture();try(var peer=new RealtimeProbe(coordinator,f.member(),"user:self")){
   jdbc.update("UPDATE group_memberships SET status='LEFT', ended_at=now() WHERE group_id=? AND user_id=?",f.group(),f.member());commit(event(f,"EXPENSE_CREATED"));assertTrue(peer.frames.isEmpty());
  }
 }
 @Test void accessChangingGroupEventUsesExplicitPersonalCacheInvalidation() throws Exception {
  Fixture f=fixture();try(var peer=new RealtimeProbe(coordinator,f.member(),"user:self")){
   commit(event(f,"GROUP_ARCHIVED"));peer.await("HOME_ACCESS_CHANGED");peer.await("CALENDAR_ACCESS_CHANGED");assertTrue(peer.frames.stream().noneMatch(s->s.contains("HOME_CHANGED")));
  }
 }

}
