package com.wedo.backend.group.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.group.entity.*;
import com.wedo.backend.group.event.GroupMembershipEndedEvent;
import com.wedo.backend.group.repository.*;
import com.wedo.backend.user.service.UserService;
import java.time.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.context.ApplicationEventPublisher;

class GroupMembershipEndedEventPublicationTest {
    private final GroupRepository groups=mock(GroupRepository.class);
    private final GroupSettingsRepository settings=mock(GroupSettingsRepository.class);
    private final GroupMembershipRepository memberships=mock(GroupMembershipRepository.class);
    private final GroupActivityLogRepository logs=mock(GroupActivityLogRepository.class);
    private final UserService users=mock(UserService.class);
    private final GroupPermissionService permissions=mock(GroupPermissionService.class);
    private final ApplicationEventPublisher events=mock(ApplicationEventPublisher.class);
    private final Instant now=Instant.parse("2026-09-15T10:00:00Z");
    private final GroupService service=new GroupService(groups,settings,memberships,logs,users,permissions,Clock.fixed(now,ZoneOffset.UTC),events);

    @Test void leaveActiveNonOwnerPublishesExactTerminalEvent() {
        UUID group=UUID.randomUUID(), member=UUID.randomUUID(); GroupMembershipEntity caller=member(group,member,GroupRole.MEMBER);
        arrangeCaller(group,member,caller); service.leave(group,member);
        GroupMembershipEndedEvent event=capture();
        assertEquals(caller.getId(),event.membershipId()); assertEquals(group,event.groupId()); assertEquals(member,event.userId());
        assertEquals(GroupRole.MEMBER,event.previousRole()); assertEquals(GroupMembershipStatus.LEFT,event.terminalStatus()); assertEquals(now,event.occurredAt());
        assertEquals(GroupMembershipStatus.LEFT,caller.getStatus());
    }

    @Test void kickActiveAllowedTargetPublishesExactTerminalEvent() {
        UUID group=UUID.randomUUID(), owner=UUID.randomUUID(), targetId=UUID.randomUUID();
        GroupMembershipEntity caller=member(group,owner,GroupRole.OWNER), target=member(group,targetId,GroupRole.ADMIN);
        arrangeCaller(group,owner,caller); when(memberships.findActiveByGroupIdAndUserIdForUpdate(group,targetId,GroupMembershipStatus.ACTIVE)).thenReturn(Optional.of(target));
        service.kick(group,targetId,owner);
        GroupMembershipEndedEvent event=capture();
        assertEquals(target.getId(),event.membershipId()); assertEquals(targetId,event.userId()); assertEquals(GroupRole.ADMIN,event.previousRole());
        assertEquals(GroupMembershipStatus.KICKED,event.terminalStatus()); assertEquals(now,event.occurredAt());
    }

    @Test void ownerLeaveAndInvalidKickPublishNothing() {
        UUID group=UUID.randomUUID(), owner=UUID.randomUUID(), targetId=UUID.randomUUID();
        arrangeCaller(group,owner,member(group,owner,GroupRole.OWNER));
        assertEquals(ErrorCode.TRANSFER_OWNERSHIP_REQUIRED,failure(()->service.leave(group,owner)).errorCode());
        verifyNoInteractions(events);

        UUID admin=UUID.randomUUID(); GroupMembershipEntity adminMember=member(group,admin,GroupRole.ADMIN), target=member(group,targetId,GroupRole.ADMIN);
        arrangeCaller(group,admin,adminMember); when(memberships.findActiveByGroupIdAndUserIdForUpdate(group,targetId,GroupMembershipStatus.ACTIVE)).thenReturn(Optional.of(target));
        assertEquals(ErrorCode.INSUFFICIENT_GROUP_PERMISSION,failure(()->service.kick(group,targetId,admin)).errorCode());
        verifyNoInteractions(events);
    }

    @Test void missingTargetAndRejectedPathDoNotPublishEventOrTriggerAfterCommitWork() {
        UUID group=UUID.randomUUID(), owner=UUID.randomUUID(), missing=UUID.randomUUID();
        arrangeCaller(group,owner,member(group,owner,GroupRole.OWNER));
        when(memberships.findActiveByGroupIdAndUserIdForUpdate(group,missing,GroupMembershipStatus.ACTIVE)).thenReturn(Optional.empty());
        assertEquals(ErrorCode.GROUP_MEMBER_NOT_FOUND,failure(()->service.kick(group,missing,owner)).errorCode());
        verifyNoInteractions(events);
        // The listener is AFTER_COMMIT; without publication on a rejected transaction, no cleanup can be scheduled.
    }

    private void arrangeCaller(UUID group,UUID user,GroupMembershipEntity caller){
        when(groups.findByIdForUpdate(group)).thenReturn(Optional.of(new GroupEntity(group,"g",null,null,GroupStatus.ACTIVE,user,now,now)));
        when(memberships.findActiveByGroupIdAndUserIdForUpdate(group,user,GroupMembershipStatus.ACTIVE)).thenReturn(Optional.of(caller));
    }
    private GroupMembershipEntity member(UUID group,UUID user,GroupRole role){return new GroupMembershipEntity(UUID.randomUUID(),group,user,role,GroupMembershipStatus.ACTIVE,now,null);}
    private GroupMembershipEndedEvent capture(){ArgumentCaptor<GroupMembershipEndedEvent> captor=ArgumentCaptor.forClass(GroupMembershipEndedEvent.class);verify(events).publishEvent(captor.capture());return captor.getValue();}
    private BusinessException failure(org.junit.jupiter.api.function.Executable action){return assertThrows(BusinessException.class,action);}
}
