package com.wedo.backend.activity.service;

import com.wedo.backend.activity.dto.*;
import com.wedo.backend.activity.entity.*;
import com.wedo.backend.activity.repository.*;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.group.entity.ChatHistoryPolicy;
import com.wedo.backend.group.entity.GroupEntity;
import com.wedo.backend.group.entity.GroupJoinPolicy;
import com.wedo.backend.group.entity.GroupMembershipEntity;
import com.wedo.backend.group.entity.GroupMembershipStatus;
import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.entity.GroupSettingsEntity;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.group.repository.GroupSettingsRepository;
import com.wedo.backend.group.service.GroupPermissionService;
import com.wedo.backend.group.service.ReadableGroupAccess;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.data.domain.Page;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;
import java.util.UUID;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class ActivityServiceTest {
    private final ActivityRepository activities=mock(ActivityRepository.class);
    private final ActivityStatusHistoryRepository histories=mock(ActivityStatusHistoryRepository.class);
    private final ActivityChangeLogRepository changes=mock(ActivityChangeLogRepository.class);
    private final GroupPermissionService permissions=mock(GroupPermissionService.class);
    private final GroupSettingsRepository settings=mock(GroupSettingsRepository.class);
    private final ActivityWaitlistSequenceRepository sequences=mock(ActivityWaitlistSequenceRepository.class);
    private final ActivityResponseFactory responses=mock(ActivityResponseFactory.class);
    private final Instant now=Instant.parse("2026-09-15T10:00:00Z");
    private final ActivityService service=new ActivityService(activities,histories,changes,permissions,settings,sequences,responses,Clock.fixed(now, ZoneOffset.UTC));

    @Test void createFoundation_startsPlanning_mapsMaxParticipantsAndPersistsInitialHistory() {
        UUID groupId=UUID.randomUUID(); UUID creatorId=UUID.randomUUID();
        when(permissions.requireMutableMembership(groupId,creatorId)).thenReturn(access(groupId,creatorId,GroupRole.OWNER,GroupStatus.ACTIVE));
        ActivityEntity saved=entity(ActivityStatus.PLANNING, now.plusSeconds(3600), null, 12);
        when(activities.save(any())).thenReturn(saved);
        when(activities.findById(saved.getId())).thenReturn(Optional.of(saved));
        when(histories.save(any())).thenAnswer(invocation -> invocation.getArgument(0));
        when(responses.detail(any(), eq(creatorId), any())).thenAnswer(invocation -> ActivityMapper.toDetail(invocation.getArgument(0)));
        ActivityDetailResponse result=service.createFoundation(groupId,creatorId,request(12));
        ArgumentCaptor<ActivityEntity> captured=ArgumentCaptor.forClass(ActivityEntity.class);
        verify(activities).save(captured.capture());
        assertEquals(ActivityStatus.PLANNING,captured.getValue().getStatus());
        assertEquals(12,captured.getValue().getCapacity());
        assertEquals(12,result.maxParticipants());
        verify(histories).save(argThat(history -> history.getFromStatus()==null && history.getToStatus()==ActivityStatus.PLANNING));
    }

    @Test void validation_rejectsInvalidTimezoneAndTimeOrder() {
        BusinessException timezone=assertThrows(BusinessException.class, () -> service.validateTimeAndTimezone(now,null,"Not/AZone"));
        assertEquals(ErrorCode.INVALID_ACTIVITY_TIME,timezone.errorCode());
        BusinessException order=assertThrows(BusinessException.class, () -> service.validateTimeAndTimezone(now,now,"UTC"));
        assertEquals(ErrorCode.INVALID_ACTIVITY_TIME,order.errorCode());
    }

    @Test void derivedLifecycle_isPlanningBeforeStart_inProgressAtStart_completedAtEnd_andKeepsCancelled() {
        assertEquals(ActivityStatus.PLANNING,service.derivedStatus(entity(ActivityStatus.PLANNING,now.plusSeconds(1),null,null),now));
        assertEquals(ActivityStatus.IN_PROGRESS,service.derivedStatus(entity(ActivityStatus.CONFIRMED,now,null,null),now));
        assertEquals(ActivityStatus.COMPLETED,service.derivedStatus(entity(ActivityStatus.CONFIRMED,now.minusSeconds(10),now,null),now));
        assertEquals(ActivityStatus.CANCELLED,service.derivedStatus(entity(ActivityStatus.CANCELLED,now.minusSeconds(10),now,null),now));
    }

    @Test void detailMapper_usesStructuredLocationAndNeverProjectsPrivateUserFields() {
        ActivityDetailResponse detail=ActivityMapper.toDetail(entity(ActivityStatus.PLANNING,now.plusSeconds(1),null,8));
        assertEquals("PHYSICAL",detail.location().type());
        assertEquals("Venue",detail.location().name());
        assertEquals(8,detail.maxParticipants());
        assertEquals(20,ActivityDetailResponse.class.getRecordComponents().length);
    }

    @Test void historyAndChangeLogPersistenceUseProvidedAuditValues() {
        ActivityEntity activity=entity(ActivityStatus.PLANNING,now.plusSeconds(1),null,null);
        when(activities.findById(activity.getId())).thenReturn(Optional.of(activity));
        when(histories.save(any())).thenAnswer(invocation -> invocation.getArgument(0));
        when(changes.save(any())).thenAnswer(invocation -> invocation.getArgument(0));
        UUID actor=UUID.randomUUID();
        assertEquals(ActivityStatus.CONFIRMED,service.persistStatusHistory(activity.getId(),ActivityStatus.PLANNING,ActivityStatus.CONFIRMED,actor,"ready",now).toStatus());
        assertEquals("title",service.persistChangeLog(activity.getId(),actor,"title","old","new",now).fieldName());
        verify(changes).save(argThat(log -> log.getActorId().equals(actor) && log.getActivityId().equals(activity.getId())));
    }

    @Test void missingActivityIsTypedNotFound() {
        when(activities.findById(any())).thenReturn(Optional.empty());
        BusinessException failure=assertThrows(BusinessException.class, () -> service.getFoundation(UUID.randomUUID(),UUID.randomUUID()));
        assertEquals(ErrorCode.ACTIVITY_NOT_FOUND,failure.errorCode());
    }

    @Test void listFoundation_delegatesReadableAccess_andAllowsArchivedAccessReturnedByM6() {
        UUID groupId=UUID.randomUUID(); UUID callerId=UUID.randomUUID();
        when(permissions.requireReadableMembership(groupId,callerId)).thenReturn(access(groupId,callerId,GroupRole.MEMBER,GroupStatus.ARCHIVED));
        when(activities.findByGroupIdOrderByStartAtAsc(eq(groupId),any())).thenReturn(Page.empty());
        assertTrue(service.listFoundation(groupId,callerId,0,30).items().isEmpty());
        verify(permissions).requireReadableMembership(groupId,callerId);

        ActivityEntity archivedActivity=entity(ActivityStatus.PLANNING,now.plusSeconds(60),null,null);
        when(activities.findById(archivedActivity.getId())).thenReturn(Optional.of(archivedActivity));
        when(responses.detail(eq(archivedActivity), eq(callerId), any())).thenReturn(ActivityMapper.toDetail(archivedActivity));
        when(permissions.requireReadableMembership(archivedActivity.getGroupId(),callerId))
                .thenReturn(access(archivedActivity.getGroupId(),callerId,GroupRole.MEMBER,GroupStatus.ARCHIVED));
        assertEquals(archivedActivity.getId(),service.getFoundation(archivedActivity.getId(),callerId).id());
    }

    @Test void listAndDetail_preserveM6DeletedAndNonMemberFailuresWithoutDuplicatingLifecycleLogic() {
        UUID groupId=UUID.randomUUID(); UUID callerId=UUID.randomUUID();
        doThrow(new BusinessException(ErrorCode.GROUP_NOT_FOUND)).when(permissions).requireReadableMembership(groupId,callerId);
        assertEquals(ErrorCode.GROUP_NOT_FOUND,assertThrows(BusinessException.class,()->service.listFoundation(groupId,callerId,0,30)).errorCode());
        ActivityEntity activity=entity(ActivityStatus.PLANNING,now.plusSeconds(60),null,null);
        when(activities.findById(activity.getId())).thenReturn(Optional.of(activity));
        doThrow(new BusinessException(ErrorCode.GROUP_NOT_FOUND)).when(permissions).requireReadableMembership(activity.getGroupId(),callerId);
        assertEquals(ErrorCode.GROUP_NOT_FOUND,assertThrows(BusinessException.class,()->service.getFoundation(activity.getId(),callerId)).errorCode());
    }

    @Test void createFoundation_ownerAndAdminAreAllowedThroughM6MutableMembership() {
        for (GroupRole role : new GroupRole[]{GroupRole.OWNER,GroupRole.ADMIN}) {
            UUID groupId=UUID.randomUUID(); UUID callerId=UUID.randomUUID();
            when(permissions.requireMutableMembership(groupId,callerId)).thenReturn(access(groupId,callerId,role,GroupStatus.ACTIVE));
            when(activities.save(any())).thenAnswer(invocation->invocation.getArgument(0));
            when(activities.findById(any())).thenReturn(Optional.of(entity(ActivityStatus.PLANNING,now.plusSeconds(60),null,null)));
            when(histories.save(any())).thenAnswer(invocation->invocation.getArgument(0));
            service.createFoundation(groupId,callerId,request(null));
        }
        verify(settings,never()).findById(any());
    }

    @Test void createFoundation_memberUsesOnlyPersistedMemberCreateActivityFlag() {
        UUID groupId=UUID.randomUUID(); UUID callerId=UUID.randomUUID();
        when(permissions.requireMutableMembership(groupId,callerId)).thenReturn(access(groupId,callerId,GroupRole.MEMBER,GroupStatus.ACTIVE));
        when(settings.findById(groupId)).thenReturn(Optional.of(groupSettings(groupId,true)));
        when(activities.save(any())).thenAnswer(invocation->invocation.getArgument(0));
        when(activities.findById(any())).thenReturn(Optional.of(entity(ActivityStatus.PLANNING,now.plusSeconds(60),null,null)));
        when(histories.save(any())).thenAnswer(invocation->invocation.getArgument(0));
        service.createFoundation(groupId,callerId,request(null));
        verify(settings).findById(groupId);
    }

    @Test void createFoundation_memberDeniedWhenPersistedMemberCreateActivityFlagIsFalse() {
        UUID groupId=UUID.randomUUID(); UUID callerId=UUID.randomUUID();
        when(permissions.requireMutableMembership(groupId,callerId)).thenReturn(access(groupId,callerId,GroupRole.MEMBER,GroupStatus.ACTIVE));
        when(settings.findById(groupId)).thenReturn(Optional.of(groupSettings(groupId,false)));
        BusinessException failure=assertThrows(BusinessException.class,()->service.createFoundation(groupId,callerId,request(null)));
        assertEquals(ErrorCode.INSUFFICIENT_GROUP_PERMISSION,failure.errorCode());
        verifyNoInteractions(activities);
    }

    private CreateActivityRequest request(Integer capacity) { return new CreateActivityRequest("Activity","description",now.plusSeconds(3600),now.plusSeconds(7200),"Asia/Ho_Chi_Minh",new ActivityLocationDto("PHYSICAL","Venue","Address",10.0,106.0),capacity); }
    private ActivityEntity entity(ActivityStatus status, Instant start, Instant end, Integer capacity) { return new ActivityEntity(UUID.randomUUID(),UUID.randomUUID(),UUID.randomUUID(),"Activity","description",status,start,end,"Asia/Ho_Chi_Minh",new ActivityLocation("PHYSICAL","Venue","Address",10.0,106.0),capacity,now,now); }
    private ReadableGroupAccess access(UUID groupId, UUID userId, GroupRole role, GroupStatus status) { return new ReadableGroupAccess(new GroupEntity(groupId,"Group",null,null,status,userId,now,now),new GroupMembershipEntity(UUID.randomUUID(),groupId,userId,role,GroupMembershipStatus.ACTIVE,now,null)); }
    private GroupSettingsEntity groupSettings(UUID groupId, boolean allowed) { return new GroupSettingsEntity(groupId,GroupJoinPolicy.AUTO_JOIN,false,allowed,false,ChatHistoryPolicy.FULL_HISTORY,now,now); }
}
