package com.wedo.backend.group.service;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.group.entity.*;
import com.wedo.backend.group.repository.*;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Instant;
import java.util.*;
import java.util.concurrent.*;

import static org.junit.jupiter.api.Assertions.*;

class GroupMembershipConcurrencyIntegrationTest extends AbstractPostgresIntegrationTest {
    private static final Instant NOW = Instant.parse("2020-01-01T00:00:00Z");
    @Autowired GroupService service; @Autowired UserRepository users; @Autowired GroupRepository groups;
    @Autowired GroupSettingsRepository settings; @Autowired GroupMembershipRepository memberships;
    @Autowired GroupActivityLogRepository logs; @Autowired JdbcTemplate jdbc; @Autowired TransactionTemplate tx;

    @Test void concurrentTransfers_serializeAndRevalidateOwner() throws Exception {
        UUID a=user(), b=user(), c=user(), g=group(a); add(g,a,GroupRole.OWNER); add(g,b,GroupRole.MEMBER); add(g,c,GroupRole.MEMBER);
        List<Result> r = race(() -> service.transferOwnership(g,b,a), () -> service.transferOwnership(g,c,a));
        assertEquals(1,r.stream().filter(Result::ok).count()); assertEquals(1,r.stream().filter(x -> x.error("INSUFFICIENT_GROUP_PERMISSION")).count());
        assertEquals(1,memberships.countByGroupIdAndRoleAndStatus(g,GroupRole.OWNER,GroupMembershipStatus.ACTIVE));
        assertEquals(1,logs.findByGroupId(g).stream().filter(x->x.getAction()==GroupActivityAction.GROUP_OWNERSHIP_TRANSFERRED).count());
        assertEquals(1,memberships.countByGroupIdAndRoleAndStatus(g,GroupRole.ADMIN,GroupMembershipStatus.ACTIVE));
        assertEquals(a,groups.findById(g).orElseThrow().getCreatedBy());
    }

    @Test void concurrentKickAndLeave_haveOneTerminalMembership() throws Exception {
        UUID a=user(), b=user(), g=group(a); add(g,a,GroupRole.OWNER); add(g,b,GroupRole.MEMBER);
        List<Result> r=race(() -> { service.kick(g,b,a); return null; }, () -> { service.leave(g,b); return null; });
        assertEquals(1,r.stream().filter(Result::ok).count());
        GroupMembershipEntity m=memberships.findByGroupIdAndUserIdAndStatus(g,b,GroupMembershipStatus.KICKED).stream().findFirst().orElse(null);
        if(m==null) m=memberships.findByGroupIdAndUserIdAndStatus(g,b,GroupMembershipStatus.LEFT).stream().findFirst().orElseThrow();
        assertNotNull(m.getEndedAt()); assertEquals(1, memberships.findByGroupIdAndUserIdAndStatus(g,b,GroupMembershipStatus.LEFT).size()
                + memberships.findByGroupIdAndUserIdAndStatus(g,b,GroupMembershipStatus.KICKED).size());
    }

    @Test void concurrentPromotes_oneSucceedsAndOneRoleTransitionFails() throws Exception {
        UUID a=user(), b=user(), g=group(a); add(g,a,GroupRole.OWNER); add(g,b,GroupRole.MEMBER);
        List<Result> r=race(() -> service.promoteAdmin(g,b,a), () -> service.promoteAdmin(g,b,a));
        assertEquals(1,r.stream().filter(Result::ok).count()); assertEquals(1,r.stream().filter(x->x.error("INVALID_GROUP_ROLE_TRANSITION")).count());
        assertEquals(GroupRole.ADMIN,memberships.findByGroupIdAndUserIdAndStatus(g,b,GroupMembershipStatus.ACTIVE).getFirst().getRole());
    }

    @Test void transferVsLeave_serializesWithoutResurrection() throws Exception {
        UUID a=user(), b=user(), g=group(a); add(g,a,GroupRole.OWNER); add(g,b,GroupRole.MEMBER);
        List<Result> r=race(() -> service.transferOwnership(g,b,a), () -> { service.leave(g,b); return null; });
        assertEquals(1,memberships.countByGroupIdAndRoleAndStatus(g,GroupRole.OWNER,GroupMembershipStatus.ACTIVE));
        boolean transferred=memberships.findByGroupIdAndUserIdAndStatus(g,b,GroupMembershipStatus.ACTIVE).stream().anyMatch(m->m.getRole()==GroupRole.OWNER);
        if (transferred) { assertEquals(GroupRole.ADMIN,memberships.findByGroupIdAndUserIdAndStatus(g,a,GroupMembershipStatus.ACTIVE).getFirst().getRole()); assertTrue(r.stream().anyMatch(x->x.error("TRANSFER_OWNERSHIP_REQUIRED"))); }
        else { assertEquals(GroupMembershipStatus.LEFT,memberships.findByGroupIdAndUserIdAndStatus(g,b,GroupMembershipStatus.LEFT).getFirst().getStatus()); assertTrue(r.stream().anyMatch(x->x.error("GROUP_MEMBER_NOT_FOUND"))); }
    }

    @Test void transferVsKick_serializesWithoutKickedOwner() throws Exception {
        UUID a=user(), b=user(), g=group(a); add(g,a,GroupRole.OWNER); add(g,b,GroupRole.MEMBER);
        List<Result> r=race(() -> service.transferOwnership(g,b,a), () -> { service.kick(g,b,a); return null; });
        assertEquals(1,memberships.countByGroupIdAndRoleAndStatus(g,GroupRole.OWNER,GroupMembershipStatus.ACTIVE));
        boolean transferred=memberships.findByGroupIdAndUserIdAndStatus(g,b,GroupMembershipStatus.ACTIVE).stream().anyMatch(m->m.getRole()==GroupRole.OWNER);
        if (transferred) assertTrue(r.stream().anyMatch(x->x.error("INSUFFICIENT_GROUP_PERMISSION")));
        else { assertEquals(GroupMembershipStatus.KICKED,memberships.findByGroupIdAndUserIdAndStatus(g,b,GroupMembershipStatus.KICKED).getFirst().getStatus()); assertTrue(r.stream().anyMatch(x->x.error("GROUP_MEMBER_NOT_FOUND"))); }
    }

    @Test void promoteVsLeaveAndDemoteVsKick_revalidateTargetUnderLock() throws Exception {
        UUID a=user(), b=user(), g=group(a); add(g,a,GroupRole.OWNER); add(g,b,GroupRole.MEMBER);
        List<Result> promoteLeave=race(() -> service.promoteAdmin(g,b,a), () -> {service.leave(g,b); return null;});
        assertEquals(1,memberships.findByGroupIdAndUserIdAndStatus(g,b,GroupMembershipStatus.LEFT).size());
        assertTrue(promoteLeave.stream().anyMatch(Result::ok));
        UUID c=user(), g2=group(a); add(g2,a,GroupRole.OWNER); add(g2,c,GroupRole.ADMIN);
        List<Result> demoteKick=race(() -> service.demoteAdmin(g2,c,a), () -> {service.kick(g2,c,a); return null;});
        GroupMembershipEntity ended=memberships.findByGroupIdAndUserIdAndStatus(g2,c,GroupMembershipStatus.KICKED).getFirst();
        assertNotNull(ended.getEndedAt()); assertTrue(ended.getRole()==GroupRole.ADMIN || ended.getRole()==GroupRole.MEMBER); assertTrue(demoteKick.stream().anyMatch(Result::ok));
    }

    @Test void ownershipTransfer_rollsBackAfterFlushedDemotion() {
        UUID a=user(), b=user(), g=group(a); add(g,a,GroupRole.OWNER); add(g,b,GroupRole.MEMBER);
        jdbc.execute("CREATE OR REPLACE FUNCTION fail_group_transfer() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.action = 'GROUP_OWNERSHIP_TRANSFERRED' THEN RAISE EXCEPTION 'test transfer log failure'; END IF; RETURN NEW; END; $$");
        jdbc.execute("CREATE TRIGGER fail_group_transfer_trigger BEFORE INSERT ON group_activity_logs FOR EACH ROW EXECUTE FUNCTION fail_group_transfer()");
        try { assertThrows(Exception.class, () -> service.transferOwnership(g,b,a)); }
        finally { jdbc.execute("DROP TRIGGER IF EXISTS fail_group_transfer_trigger ON group_activity_logs"); jdbc.execute("DROP FUNCTION IF EXISTS fail_group_transfer()"); }
        assertEquals(GroupRole.OWNER,memberships.findByGroupIdAndUserIdAndStatus(g,a,GroupMembershipStatus.ACTIVE).getFirst().getRole());
        assertEquals(GroupRole.MEMBER,memberships.findByGroupIdAndUserIdAndStatus(g,b,GroupMembershipStatus.ACTIVE).getFirst().getRole());
        assertEquals(1,memberships.countByGroupIdAndRoleAndStatus(g,GroupRole.OWNER,GroupMembershipStatus.ACTIVE));
        assertEquals(0,logs.findByGroupId(g).stream().filter(x->x.getAction()==GroupActivityAction.GROUP_OWNERSHIP_TRANSFERRED).count());
    }

    private List<Result> race(Callable<?> x, Callable<?> y) throws Exception {
        ExecutorService pool=Executors.newFixedThreadPool(2); CountDownLatch ready=new CountDownLatch(2), start=new CountDownLatch(1);
        Callable<Result> w1=worker(x,ready,start), w2=worker(y,ready,start);
        Future<Result> f1=pool.submit(w1), f2=pool.submit(w2); assertTrue(ready.await(10,TimeUnit.SECONDS)); start.countDown(); List<Result> out=List.of(f1.get(20,TimeUnit.SECONDS),f2.get(20,TimeUnit.SECONDS)); pool.shutdownNow(); return out;
    }
    private Callable<Result> worker(Callable<?> c,CountDownLatch ready,CountDownLatch start){ return ()->{ready.countDown(); start.await(); try{return new Result(c.call(),null);}catch(Exception e){return new Result(null,e);}}; }
    private record Result(Object value,Exception exception){boolean ok(){return exception==null;} boolean error(String code){return exception instanceof BusinessException b && b.errorCode().name().equals(code);}}
    private UUID user(){UUID id=UUID.randomUUID(); users.saveAndFlush(new UserEntity(id,"cc."+id+"@e.com","cc_"+id.toString().substring(0,8),"C",UserStatus.ACTIVE,NOW,NOW)); return id;}
    private UUID group(UUID owner){UUID id=UUID.randomUUID(); groups.saveAndFlush(new GroupEntity(id,"G",null,null,GroupStatus.ACTIVE,owner,NOW,NOW)); settings.saveAndFlush(GroupSettingsEntity.createDefault(id,NOW)); return id;}
    private void add(UUID g,UUID u,GroupRole r){memberships.saveAndFlush(new GroupMembershipEntity(UUID.randomUUID(),g,u,r,GroupMembershipStatus.ACTIVE,NOW,null));}
}
