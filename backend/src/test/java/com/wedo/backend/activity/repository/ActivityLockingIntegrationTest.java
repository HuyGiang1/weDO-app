package com.wedo.backend.activity.repository;

import com.wedo.backend.activity.entity.*;
import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.group.entity.*;
import com.wedo.backend.group.repository.GroupRepository;
import com.wedo.backend.user.entity.*;
import com.wedo.backend.user.repository.UserRepository;
import java.time.Instant;
import java.util.UUID;
import java.util.concurrent.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import static org.junit.jupiter.api.Assertions.*;

class ActivityLockingIntegrationTest extends AbstractPostgresIntegrationTest {
  @Autowired ActivityRepository activities; @Autowired ActivityParticipantRepository participants; @Autowired ActivityWaitlistSequenceRepository sequences;
  @Autowired GroupRepository groups; @Autowired UserRepository users; @Autowired PlatformTransactionManager transactionManager;
  private static final Instant NOW=Instant.parse("2026-09-15T12:00:00Z");

  @Test void activityParticipantAndSequenceLocks_blockSameRowButNotDifferentParticipant() throws Exception {
    UUID owner=user(); UUID groupId=UUID.randomUUID(); groups.save(new GroupEntity(groupId,"g",null,null,GroupStatus.ACTIVE,owner,NOW,NOW));
    UUID activityId=UUID.randomUUID(); activities.save(new ActivityEntity(activityId,groupId,owner,"a",null,ActivityStatus.CONFIRMED,NOW.plusSeconds(3600),null,"UTC",new ActivityLocation("PHYSICAL","v",null,null,null),2,NOW,NOW));
    UUID one=user(), two=user(); participants.save(new ActivityParticipantEntity(UUID.randomUUID(),activityId,one,ActivityRsvpStatus.WAITLIST,1L,NOW,NOW,NOW)); participants.save(new ActivityParticipantEntity(UUID.randomUUID(),activityId,two,ActivityRsvpStatus.WAITLIST,2L,NOW,NOW,NOW)); sequences.save(new ActivityWaitlistSequenceEntity(activityId,2,NOW));
    assertLockBlocks(() -> activities.findByIdForUpdate(activityId));
    assertLockBlocks(() -> participants.findByActivityIdAndUserIdForUpdate(activityId,one));
    assertLockBlocks(() -> sequences.findByActivityIdForUpdate(activityId));
    TransactionTemplate tx=new TransactionTemplate(transactionManager); assertTrue(Boolean.TRUE.equals(tx.execute(s -> participants.findByActivityIdAndUserIdForUpdate(activityId,two).isPresent())));
  }
  private void assertLockBlocks(Callable<?> lock) throws Exception {
    TransactionTemplate tx=new TransactionTemplate(transactionManager); CountDownLatch held=new CountDownLatch(1), release=new CountDownLatch(1), entered=new CountDownLatch(1); ExecutorService pool=Executors.newFixedThreadPool(2);
    try { Future<?> a=pool.submit(() -> tx.execute(s->{ try { lock.call(); held.countDown(); assertTrue(release.await(10,TimeUnit.SECONDS)); } catch(Exception e){throw new RuntimeException(e);} return null;})); assertTrue(held.await(10,TimeUnit.SECONDS)); Future<?> b=pool.submit(() -> tx.execute(s->{try{lock.call();entered.countDown();}catch(Exception e){throw new RuntimeException(e);}return null;})); assertFalse(entered.await(300,TimeUnit.MILLISECONDS)); release.countDown(); a.get(10,TimeUnit.SECONDS); b.get(10,TimeUnit.SECONDS); assertTrue(entered.await(1,TimeUnit.SECONDS)); } finally { pool.shutdownNow(); assertTrue(pool.awaitTermination(10,TimeUnit.SECONDS)); }
  }
  private UUID user(){UUID id=UUID.randomUUID();users.save(new UserEntity(id,"l"+id+"@t.local","l"+id.toString().substring(0,8),"L",UserStatus.ACTIVE,NOW,NOW));return id;}
}
