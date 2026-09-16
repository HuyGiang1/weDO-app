package com.wedo.backend.activity.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.wedo.backend.activity.dto.ActivityLocationDto;
import com.wedo.backend.activity.dto.UpdateActivityRequest;
import com.wedo.backend.activity.entity.*;
import com.wedo.backend.activity.repository.*;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.group.entity.*;
import com.wedo.backend.group.service.GroupPermissionService;
import com.wedo.backend.group.service.ReadableGroupAccess;
import java.time.*;
import java.util.*;
import org.junit.jupiter.api.Test;

class ActivityLifecycleServiceTest {
    private final ActivityRepository activities = mock(ActivityRepository.class);
    private final ActivityParticipantRepository participants = mock(ActivityParticipantRepository.class);
    private final ActivityStatusHistoryRepository histories = mock(ActivityStatusHistoryRepository.class);
    private final ActivityChangeLogRepository changes = mock(ActivityChangeLogRepository.class);
    private final GroupPermissionService permissions = mock(GroupPermissionService.class);
    private final ActivityRsvpService rsvps = mock(ActivityRsvpService.class);
    private final ActivityResponseFactory responses = mock(ActivityResponseFactory.class);
    private final Instant now = Instant.parse("2026-09-15T10:00:00Z");
    private final ActivityLifecycleService service = new ActivityLifecycleService(activities, participants, histories, changes,
            permissions, rsvps, responses, Clock.fixed(now, ZoneOffset.UTC));

    @Test void confirm_planningTransitionsAndOtherLifecycleStatesAreRejected() {
        UUID actor = UUID.randomUUID();
        ActivityEntity planning = activity(ActivityStatus.PLANNING, null, 8);
        arrangeAuthorized(planning, actor, GroupRole.OWNER);
        service.confirm(planning.getId(), actor);
        assertEquals(ActivityStatus.CONFIRMED, planning.getStatus());
        verify(histories).save(argThat(h -> h.getFromStatus() == ActivityStatus.PLANNING && h.getToStatus() == ActivityStatus.CONFIRMED));

        ActivityEntity confirmed = activity(ActivityStatus.CONFIRMED, null, 8);
        arrangeAuthorized(confirmed, actor, GroupRole.OWNER);
        assertEquals(ErrorCode.ACTIVITY_CLOSED, failure(() -> service.confirm(confirmed.getId(), actor)).errorCode());
    }

    @Test void cancel_matrixHasExplicitLifecycleErrors() {
        UUID actor = UUID.randomUUID();
        ActivityEntity planning = activity(ActivityStatus.PLANNING, null, 8); arrangeAuthorized(planning, actor, GroupRole.ADMIN);
        service.cancel(planning.getId(), actor, "reason"); assertEquals(ActivityStatus.CANCELLED, planning.getStatus());
        ActivityEntity inProgress = activity(ActivityStatus.CONFIRMED, null, 8, now.minusSeconds(1)); arrangeAuthorized(inProgress, actor, GroupRole.ADMIN);
        assertEquals(ErrorCode.ACTIVITY_ALREADY_STARTED, failure(() -> service.cancel(inProgress.getId(), actor, null)).errorCode());
        ActivityEntity completed = activity(ActivityStatus.COMPLETED, null, 8); arrangeAuthorized(completed, actor, GroupRole.ADMIN);
        assertEquals(ErrorCode.ACTIVITY_ALREADY_COMPLETED, failure(() -> service.cancel(completed.getId(), actor, null)).errorCode());
        ActivityEntity cancelled = activity(ActivityStatus.CANCELLED, null, 8); arrangeAuthorized(cancelled, actor, GroupRole.ADMIN);
        assertEquals(ErrorCode.ACTIVITY_CLOSED, failure(() -> service.cancel(cancelled.getId(), actor, null)).errorCode());
    }

    @Test void complete_allowsAuthorizedConfirmedOrInProgressOnlyWhenEndIsAbsent() {
        UUID actor = UUID.randomUUID();
        ActivityEntity confirmed = activity(ActivityStatus.CONFIRMED, null, 8); arrangeAuthorized(confirmed, actor, GroupRole.OWNER);
        service.complete(confirmed.getId(), actor); assertEquals(ActivityStatus.COMPLETED, confirmed.getStatus());
        ActivityEntity withEnd = activity(ActivityStatus.CONFIRMED, now.plusSeconds(30), 8); arrangeAuthorized(withEnd, actor, GroupRole.OWNER);
        assertEquals(ErrorCode.ACTIVITY_ALREADY_STARTED, failure(() -> service.complete(withEnd.getId(), actor)).errorCode());
        ActivityEntity planning = activity(ActivityStatus.PLANNING, null, 8); arrangeAuthorized(planning, actor, GroupRole.OWNER);
        assertEquals(ErrorCode.ACTIVITY_CLOSED, failure(() -> service.complete(planning.getId(), actor)).errorCode());
    }

    @Test void actorMatrixAllowsCreatorOwnerAdminButNotUnrelatedMember() {
        UUID creator = UUID.randomUUID(); UUID owner = UUID.randomUUID(); UUID admin = UUID.randomUUID(); UUID member = UUID.randomUUID();
        for (UUID actor : List.of(creator, owner, admin)) {
            ActivityEntity a = activity(ActivityStatus.PLANNING, null, 8, now.plusSeconds(60), creator);
            arrangeAuthorized(a, actor, actor.equals(owner) ? GroupRole.OWNER : actor.equals(admin) ? GroupRole.ADMIN : GroupRole.MEMBER);
            service.confirm(a.getId(), actor);
        }
        ActivityEntity denied = activity(ActivityStatus.PLANNING, null, 8, now.plusSeconds(60), creator);
        arrangeAuthorized(denied, member, GroupRole.MEMBER);
        assertEquals(ErrorCode.INSUFFICIENT_GROUP_PERMISSION, failure(() -> service.confirm(denied.getId(), member)).errorCode());
    }

    @Test void edit_matrixLocksTerminalAndInProgressTimeWhileRejectingCapacityBelowGoing() {
        UUID actor = UUID.randomUUID();
        ActivityEntity inProgress = activity(ActivityStatus.CONFIRMED, null, 8, now.minusSeconds(1), actor); arrangeAuthorized(inProgress, actor, GroupRole.MEMBER);
        assertEquals(ErrorCode.ACTIVITY_ALREADY_STARTED, failure(() -> service.update(inProgress.getId(), actor, update(null, now.plusSeconds(1), null, null))).errorCode());
        ActivityEntity completed = activity(ActivityStatus.COMPLETED, null, 8); arrangeAuthorized(completed, actor, GroupRole.OWNER);
        assertEquals(ErrorCode.ACTIVITY_ALREADY_COMPLETED, failure(() -> service.update(completed.getId(), actor, update("x", null, null, null))).errorCode());
        ActivityEntity planning = activity(ActivityStatus.PLANNING, null, 8); arrangeAuthorized(planning, actor, GroupRole.OWNER);
        when(participants.countByActivityIdAndRsvpStatus(planning.getId(), ActivityRsvpStatus.GOING)).thenReturn(5L);
        assertEquals(ErrorCode.ACTIVITY_CAPACITY_INVALID, failure(() -> service.update(planning.getId(), actor, update(null, null, null, 4))).errorCode());
    }

    private void arrangeAuthorized(ActivityEntity activity, UUID actor, GroupRole role) {
        when(activities.findByIdForUpdate(activity.getId())).thenReturn(Optional.of(activity));
        ReadableGroupAccess access = access(activity.getGroupId(), actor, role);
        when(permissions.requireMutableMembership(activity.getGroupId(), actor)).thenReturn(access);
        when(permissions.requireReadableMembership(activity.getGroupId(), actor)).thenReturn(access);
        when(responses.detail(eq(activity), eq(actor), any())).thenReturn(ActivityMapper.toDetail(activity));
    }
    private ActivityEntity activity(ActivityStatus status, Instant end, Integer capacity) { return activity(status, end, capacity, now.plusSeconds(3600), UUID.randomUUID()); }
    private ActivityEntity activity(ActivityStatus status, Instant end, Integer capacity, Instant start) { return activity(status, end, capacity, start, UUID.randomUUID()); }
    private ActivityEntity activity(ActivityStatus status, Instant end, Integer capacity, Instant start, UUID creator) { return new ActivityEntity(UUID.randomUUID(), UUID.randomUUID(), creator, "title", "description", status, start, end, "UTC", null, capacity, now, now); }
    private ReadableGroupAccess access(UUID groupId, UUID user, GroupRole role) { return new ReadableGroupAccess(new GroupEntity(groupId,"g",null,null,GroupStatus.ACTIVE,user,now,now),new GroupMembershipEntity(UUID.randomUUID(),groupId,user,role,GroupMembershipStatus.ACTIVE,now,null)); }
    private UpdateActivityRequest update(String title, Instant start, Instant end, Integer capacity) { return new UpdateActivityRequest(title,null,start,end,null,null,capacity); }
    private BusinessException failure(org.junit.jupiter.api.function.Executable action) { return assertThrows(BusinessException.class, action); }
}
