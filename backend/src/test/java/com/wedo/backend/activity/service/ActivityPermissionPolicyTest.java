package com.wedo.backend.activity.service;

import static org.junit.jupiter.api.Assertions.*;

import com.wedo.backend.activity.entity.*;
import com.wedo.backend.group.entity.*;
import com.wedo.backend.group.service.ReadableGroupAccess;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class ActivityPermissionPolicyTest {
    @Test void creatorOwnerAndAdminGetOnlyLifecycleAppropriateManagementCapabilities() {
        UUID creator=UUID.randomUUID(); ActivityEntity planning=activity(creator,ActivityStatus.PLANNING,null);
        var creatorFlags=ActivityPermissionPolicy.forCaller(planning,access(planning.getGroupId(),creator,GroupRole.MEMBER),creator,ActivityStatus.PLANNING);
        assertTrue(creatorFlags.canEdit()); assertTrue(creatorFlags.canConfirm()); assertTrue(creatorFlags.canCancel()); assertFalse(creatorFlags.canComplete()); assertTrue(creatorFlags.canRsvp());
        UUID admin=UUID.randomUUID();
        var adminFlags=ActivityPermissionPolicy.forCaller(planning,access(planning.getGroupId(),admin,GroupRole.ADMIN),admin,ActivityStatus.PLANNING);
        assertTrue(adminFlags.canEdit());
    }
    @Test void closedActivitiesLockRsvpAndAllManagementCapabilities() {
        UUID user=UUID.randomUUID(); ActivityEntity completed=activity(user,ActivityStatus.COMPLETED,null);
        var flags=ActivityPermissionPolicy.forCaller(completed,access(completed.getGroupId(),user,GroupRole.OWNER),user,ActivityStatus.COMPLETED);
        assertFalse(flags.canEdit()); assertFalse(flags.canConfirm()); assertFalse(flags.canCancel()); assertFalse(flags.canComplete()); assertFalse(flags.canRsvp());
    }
    @Test void manualCompletionRequiresManagerConfirmedOrInProgressAndNoEndAt() {
        UUID user=UUID.randomUUID(); ActivityEntity manual=activity(user,ActivityStatus.CONFIRMED,null);
        assertTrue(ActivityPermissionPolicy.forCaller(manual,access(manual.getGroupId(),user,GroupRole.MEMBER),user,ActivityStatus.CONFIRMED).canComplete());
        ActivityEntity timed=activity(user,ActivityStatus.CONFIRMED,Instant.now().plusSeconds(60));
        assertFalse(ActivityPermissionPolicy.forCaller(timed,access(timed.getGroupId(),user,GroupRole.MEMBER),user,ActivityStatus.CONFIRMED).canComplete());
    }
    private ActivityEntity activity(UUID creator,ActivityStatus status,Instant end){Instant now=Instant.now();return new ActivityEntity(UUID.randomUUID(),UUID.randomUUID(),creator,"t",null,status,now.plusSeconds(60),end,"UTC",null,null,now,now);}
    private ReadableGroupAccess access(UUID group,UUID user,GroupRole role){Instant now=Instant.now();return new ReadableGroupAccess(new GroupEntity(group,"g",null,null,GroupStatus.ACTIVE,user,now,now),new GroupMembershipEntity(UUID.randomUUID(),group,user,role,GroupMembershipStatus.ACTIVE,now,null));}
}
