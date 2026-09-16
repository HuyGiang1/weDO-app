package com.wedo.backend.activity.service;

import com.wedo.backend.activity.dto.*;
import com.wedo.backend.activity.entity.*;
import com.wedo.backend.activity.repository.ActivityChangeLogRepository;
import com.wedo.backend.activity.repository.ActivityRepository;
import com.wedo.backend.activity.repository.ActivityStatusHistoryRepository;
import com.wedo.backend.activity.repository.ActivityWaitlistSequenceRepository;
import com.wedo.backend.common.dto.PagedResponse;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.entity.GroupSettingsEntity;
import com.wedo.backend.group.repository.GroupSettingsRepository;
import com.wedo.backend.group.service.GroupPermissionService;
import com.wedo.backend.group.service.ReadableGroupAccess;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;
import java.time.zone.ZoneRulesException;
import java.util.UUID;

/** M7 persistence/read foundation only; it deliberately has no RSVP orchestration. */
@Service
public class ActivityService {
    private final ActivityRepository activityRepository;
    private final ActivityStatusHistoryRepository statusHistoryRepository;
    private final ActivityChangeLogRepository changeLogRepository;
    private final GroupPermissionService groupPermissionService;
    private final GroupSettingsRepository groupSettingsRepository;
    private final ActivityWaitlistSequenceRepository waitlistSequences;
    private final ActivityResponseFactory responses;
    private final Clock clock;
    public ActivityService(ActivityRepository activityRepository, ActivityStatusHistoryRepository statusHistoryRepository, ActivityChangeLogRepository changeLogRepository, GroupPermissionService groupPermissionService, GroupSettingsRepository groupSettingsRepository, ActivityWaitlistSequenceRepository waitlistSequences, ActivityResponseFactory responses, Clock clock) {
        this.activityRepository=activityRepository; this.statusHistoryRepository=statusHistoryRepository; this.changeLogRepository=changeLogRepository; this.groupPermissionService=groupPermissionService; this.groupSettingsRepository=groupSettingsRepository; this.waitlistSequences=waitlistSequences; this.responses=responses; this.clock=clock;
    }
    /** Internal seam; no HTTP command exposes incomplete M7 participant semantics. */
    @Transactional
    public ActivityDetailResponse createFoundation(UUID groupId, UUID creatorId, CreateActivityRequest request) {
        ReadableGroupAccess access = groupPermissionService.requireMutableMembership(groupId, creatorId);
        requireCreatePermission(access);
        validateCreateRequest(request);
        Instant now=clock.instant();
        ActivityEntity activity=activityRepository.save(new ActivityEntity(UUID.randomUUID(), groupId, creatorId, request.title().trim(), request.description(), ActivityStatus.PLANNING, request.startAt(), request.endAt(), request.timezone().trim(), ActivityLocation.from(request.location()), request.maxParticipants(), now, now));
        waitlistSequences.save(new ActivityWaitlistSequenceEntity(activity.getId(), 0, now));
        persistStatusHistory(activity.getId(), null, ActivityStatus.PLANNING, creatorId, null, now);
        return responses.detail(activity, creatorId, access);
    }
    @Transactional(readOnly=true)
    public PagedResponse<ActivitySummaryResponse> listFoundation(UUID groupId, UUID callerUserId, int page, int size) {
        groupPermissionService.requireReadableMembership(groupId, callerUserId);
        Page<ActivityEntity> activities=activityRepository.findByGroupIdOrderByStartAtAsc(groupId, PageRequest.of(page,size));
        return PagedResponse.from(activities, activities.getContent().stream().map(a -> responses.summary(a, callerUserId)).toList());
    }
    @Transactional(readOnly=true)
    public ActivityDetailResponse getFoundation(UUID activityId, UUID callerUserId) {
        ActivityEntity activity = requireActivity(activityId);
        ReadableGroupAccess access = groupPermissionService.requireReadableMembership(activity.getGroupId(), callerUserId);
        return responses.detail(activity, callerUserId, access);
    }
    @Transactional
    public ActivityStatusHistoryResponse persistStatusHistory(UUID activityId, ActivityStatus from, ActivityStatus to, UUID actorId, String reason, Instant at) {
        requireActivity(activityId);
        ActivityStatusHistoryEntity saved=statusHistoryRepository.save(new ActivityStatusHistoryEntity(UUID.randomUUID(),activityId,from,to,actorId,reason,at));
        return new ActivityStatusHistoryResponse(saved.getId(),saved.getFromStatus(),saved.getToStatus(),saved.getChangedBy(),saved.getReason(),saved.getCreatedAt());
    }
    @Transactional
    public ActivityChangeLogResponse persistChangeLog(UUID activityId, UUID actorId, String fieldName, String oldValue, String newValue, Instant at) {
        requireActivity(activityId);
        ActivityChangeLogEntity saved=changeLogRepository.save(new ActivityChangeLogEntity(UUID.randomUUID(),activityId,actorId,fieldName,oldValue,newValue,at));
        return new ActivityChangeLogResponse(saved.getId(),saved.getActorId(),saved.getFieldName(),saved.getOldValue(),saved.getNewValue(),saved.getCreatedAt());
    }
    public ActivityStatus derivedStatus(ActivityEntity activity, Instant now) {
        if (activity.getStatus()==ActivityStatus.CANCELLED) return ActivityStatus.CANCELLED;
        if (activity.getEndAt()!=null && !now.isBefore(activity.getEndAt())) return ActivityStatus.COMPLETED;
        if (!now.isBefore(activity.getStartAt())) return ActivityStatus.IN_PROGRESS;
        return activity.getStatus();
    }
    public void validateCreateRequest(CreateActivityRequest request) { validateTimeAndTimezone(request.startAt(),request.endAt(),request.timezone()); if(request.maxParticipants()!=null && request.maxParticipants()<=0) throw new BusinessException(ErrorCode.ACTIVITY_CAPACITY_INVALID); }
    public void validateTimeAndTimezone(Instant startAt, Instant endAt, String timezone) {
        if(startAt==null || (endAt!=null && !endAt.isAfter(startAt))) throw new BusinessException(ErrorCode.INVALID_ACTIVITY_TIME);
        try { ZoneId.of(timezone); } catch (ZoneRulesException | NullPointerException exception) { throw new BusinessException(ErrorCode.INVALID_ACTIVITY_TIME,"Invalid IANA timezone."); }
    }
    private void requireCreatePermission(ReadableGroupAccess access) {
        GroupRole role = access.membership().getRole();
        if (role == GroupRole.OWNER || role == GroupRole.ADMIN) return;
        GroupSettingsEntity settings = groupSettingsRepository.findById(access.group().getId())
                .orElseThrow(() -> new IllegalStateException("Group settings missing"));
        if (!settings.isMemberCreateActivityAllowed()) {
            throw new BusinessException(ErrorCode.INSUFFICIENT_GROUP_PERMISSION);
        }
    }
    private ActivityEntity requireActivity(UUID activityId) { return activityRepository.findById(activityId).orElseThrow(() -> new BusinessException(ErrorCode.ACTIVITY_NOT_FOUND)); }
}
