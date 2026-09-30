package com.wedo.backend.activity.service;

import com.wedo.backend.activity.dto.*;
import com.wedo.backend.activity.entity.*;
import com.wedo.backend.activity.repository.*;
import com.wedo.backend.activity.reminder.ActivityReminderService;
import com.wedo.backend.common.error.*;
import com.wedo.backend.group.entity.GroupActivityAction;
import com.wedo.backend.group.entity.GroupActivityLogEntity;
import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.repository.GroupActivityLogRepository;
import com.wedo.backend.group.service.GroupPermissionService;
import com.wedo.backend.group.service.ReadableGroupAccess;
import java.time.*;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ActivityLifecycleService {
    private final ActivityRepository activities;
    private final ActivityParticipantRepository participants;
    private final ActivityStatusHistoryRepository statusHistory;
    private final ActivityChangeLogRepository changes;
    private final GroupPermissionService permissions;
    private final ActivityRsvpService rsvps;
    private final ActivityResponseFactory responses;
    private final GroupActivityLogRepository groupActivityLogRepository;
    private final ActivityReminderService reminders;
    private final Clock clock;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private org.springframework.context.ApplicationEventPublisher eventPublisher;

    public ActivityLifecycleService(ActivityRepository activities,
                                    ActivityParticipantRepository participants,
                                    ActivityStatusHistoryRepository statusHistory,
                                    ActivityChangeLogRepository changes,
                                    GroupPermissionService permissions,
                                    ActivityRsvpService rsvps,
                                    ActivityResponseFactory responses,
                                    GroupActivityLogRepository groupActivityLogRepository,
                                    ActivityReminderService reminders,
                                    Clock clock) {
        this.activities = activities;
        this.participants = participants;
        this.statusHistory = statusHistory;
        this.changes = changes;
        this.permissions = permissions;
        this.rsvps = rsvps;
        this.responses = responses;
        this.groupActivityLogRepository = groupActivityLogRepository;
        this.reminders = reminders;
        this.clock = clock;
    }

    @Transactional
    public ActivityDetailResponse confirm(UUID id, UUID actor) {
        ActivityEntity a = lockedAuthorized(id, actor);
        if (a.getStatus() != ActivityStatus.PLANNING) {
            throw new BusinessException(a.getStatus() == ActivityStatus.COMPLETED ? ErrorCode.ACTIVITY_ALREADY_COMPLETED : ErrorCode.ACTIVITY_CLOSED);
        }
        transition(a, ActivityStatus.CONFIRMED, actor, null);
        groupActivityLogRepository.save(new GroupActivityLogEntity(UUID.randomUUID(), a.getGroupId(), actor, GroupActivityAction.ACTIVITY_CONFIRMED, clock.instant()));
        return response(a, actor);
    }

    @Transactional
    public ActivityDetailResponse cancel(UUID id, UUID actor, String reason) {
        ActivityEntity a = lockedAuthorized(id, actor);
        ActivityStatus effective = effective(a, clock.instant());
        if (effective == ActivityStatus.IN_PROGRESS) throw new BusinessException(ErrorCode.ACTIVITY_ALREADY_STARTED);
        if (effective == ActivityStatus.COMPLETED) throw new BusinessException(ErrorCode.ACTIVITY_ALREADY_COMPLETED);
        if (effective == ActivityStatus.CANCELLED) throw new BusinessException(ErrorCode.ACTIVITY_CLOSED);
        transition(a, ActivityStatus.CANCELLED, actor, reason);
        groupActivityLogRepository.save(new GroupActivityLogEntity(UUID.randomUUID(), a.getGroupId(), actor, GroupActivityAction.ACTIVITY_CANCELLED, clock.instant()));
        return response(a, actor);
    }

    @Transactional
    public ActivityDetailResponse complete(UUID id, UUID actor) {
        ActivityEntity a = lockedAuthorized(id, actor);
        if (a.getEndAt() != null) throw new BusinessException(ErrorCode.ACTIVITY_ALREADY_STARTED);
        ActivityStatus effective = effective(a, clock.instant());
        if (effective != ActivityStatus.CONFIRMED && effective != ActivityStatus.IN_PROGRESS) {
            throw new BusinessException(effective == ActivityStatus.COMPLETED ? ErrorCode.ACTIVITY_ALREADY_COMPLETED : ErrorCode.ACTIVITY_CLOSED);
        }
        transition(a, ActivityStatus.COMPLETED, actor, null);
        groupActivityLogRepository.save(new GroupActivityLogEntity(UUID.randomUUID(), a.getGroupId(), actor, GroupActivityAction.ACTIVITY_COMPLETED, clock.instant()));
        return response(a, actor);
    }

    @Transactional
    public ActivityDetailResponse update(UUID id, UUID actor, UpdateActivityRequest r) {
        ActivityEntity a = lockedAuthorized(id, actor);
        Instant now = clock.instant();
        ActivityStatus s = effective(a, now);
        if (s == ActivityStatus.COMPLETED) throw new BusinessException(ErrorCode.ACTIVITY_ALREADY_COMPLETED);
        if (s == ActivityStatus.CANCELLED) throw new BusinessException(ErrorCode.ACTIVITY_CLOSED);
        String title = r.title() == null ? a.getTitle() : r.title().trim();
        String desc = r.description() == null ? a.getDescription() : r.description();
        Instant start = r.startAt() == null ? a.getStartAt() : r.startAt();
        Instant end = r.endAt() == null ? a.getEndAt() : r.endAt();
        String zone = r.timezone() == null ? a.getTimezone() : (r.timezone().isBlank() ? null : r.timezone().trim());
        ActivityLocation loc = r.location() == null ? a.getLocation() : ActivityLocation.from(r.location());
        Integer cap = r.maxParticipants() == null ? a.getCapacity() : r.maxParticipants();

        if (s == ActivityStatus.IN_PROGRESS && (r.startAt() != null || r.endAt() != null || r.timezone() != null || r.location() != null)) {
            throw new BusinessException(ErrorCode.ACTIVITY_ALREADY_STARTED);
        }
        if (s == ActivityStatus.IN_PROGRESS && r.maxParticipants() != null && (a.getCapacity() == null || r.maxParticipants() < a.getCapacity())) {
            throw new BusinessException(ErrorCode.ACTIVITY_ALREADY_STARTED);
        }
        validate(start, end, zone, cap);
        long going = participants.countByActivityIdAndRsvpStatus(id, ActivityRsvpStatus.GOING);
        if (cap != null && cap < going) throw new BusinessException(ErrorCode.ACTIVITY_CAPACITY_INVALID);
        Integer oldCapacity = a.getCapacity();
        boolean confirmedScheduleChanged = false;
        boolean confirmedLocationChanged = false;
        if (s == ActivityStatus.CONFIRMED) {
            confirmedScheduleChanged = !Objects.equals(a.getStartAt(), start)
                    || !Objects.equals(a.getEndAt(), end)
                    || !Objects.equals(a.getTimezone(), zone);
            confirmedLocationChanged = !Objects.equals(a.getLocation(), loc);
            logIfChanged(a, actor, "startAt", a.getStartAt(), start, now);
            logIfChanged(a, actor, "endAt", a.getEndAt(), end, now);
            logIfChanged(a, actor, "timezone", a.getTimezone(), zone, now);
            if (confirmedLocationChanged) {
                changes.save(new ActivityChangeLogEntity(UUID.randomUUID(), id, actor, "location", String.valueOf(a.getLocation()), String.valueOf(loc), now));
            }
        }
        boolean startChanged = !Objects.equals(a.getStartAt(), start);
        a.update(title, desc, start, end, zone, loc, cap, now);
        if (startChanged) reminders.rescheduleForActivity(a.getId(), start, now);
        if (confirmedScheduleChanged || confirmedLocationChanged) {
            publishConfirmedDetailsChanged(a, actor, now, confirmedScheduleChanged, confirmedLocationChanged);
        }
        if ((oldCapacity != null && (cap == null || cap > oldCapacity)) && s != ActivityStatus.IN_PROGRESS) {
            rsvps.promoteAll(a, now);
        }
        groupActivityLogRepository.save(new GroupActivityLogEntity(UUID.randomUUID(), a.getGroupId(), actor, GroupActivityAction.ACTIVITY_UPDATED, now));
        return response(a, actor);
    }

    private void publishConfirmedDetailsChanged(
            ActivityEntity activity,
            UUID actorId,
            Instant occurredAt,
            boolean scheduleChanged,
            boolean locationChanged
    ) {
        if (eventPublisher == null) return;
        LinkedHashSet<UUID> recipients = new LinkedHashSet<>();
        recipients.addAll(participants.findByActivityIdAndRsvpStatusOrderByWaitlistSequenceAsc(
                activity.getId(), ActivityRsvpStatus.GOING).stream().map(ActivityParticipantEntity::getUserId).toList());
        recipients.addAll(participants.findByActivityIdAndRsvpStatusOrderByWaitlistSequenceAsc(
                activity.getId(), ActivityRsvpStatus.MAYBE).stream().map(ActivityParticipantEntity::getUserId).toList());
        recipients.remove(actorId);
        if (recipients.isEmpty()) return;

        permissions.requireReadableMembership(activity.getGroupId(), actorId);
        if (scheduleChanged) {
            eventPublisher.publishEvent(new com.wedo.backend.notification.event.NotificationDomainEvent(
                    "ACTIVITY_TIME_CHANGED:" + activity.getId() + ":" + occurredAt.toEpochMilli(),
                    "ACTIVITY_TIME_CHANGED",
                    "ACTIVITY",
                    "NORMAL",
                    false,
                    actorId,
                    activity.getGroupId(),
                    List.copyOf(recipients),
                    "Thời gian hoạt động đã thay đổi",
                    "Thời gian của hoạt động " + activity.getTitle() + " đã thay đổi.",
                    "ACTIVITY",
                    activity.getId(),
                    "/activities/detail",
                    Map.of("groupId", activity.getGroupId().toString(), "activityId", activity.getId().toString()),
                    occurredAt
            ));
        }
        if (locationChanged) {
            eventPublisher.publishEvent(new com.wedo.backend.notification.event.NotificationDomainEvent(
                    "ACTIVITY_LOCATION_CHANGED:" + activity.getId() + ":" + occurredAt.toEpochMilli(),
                    "ACTIVITY_LOCATION_CHANGED",
                    "ACTIVITY",
                    "NORMAL",
                    false,
                    actorId,
                    activity.getGroupId(),
                    List.copyOf(recipients),
                    "Địa điểm hoạt động đã thay đổi",
                    "Địa điểm của hoạt động " + activity.getTitle() + " đã thay đổi.",
                    "ACTIVITY",
                    activity.getId(),
                    "/activities/detail",
                    Map.of("groupId", activity.getGroupId().toString(), "activityId", activity.getId().toString()),
                    occurredAt
            ));
        }
    }

    private ActivityEntity lockedAuthorized(UUID id, UUID actor) {
        ActivityEntity a = activities.findByIdForUpdate(id).orElseThrow(() -> new BusinessException(ErrorCode.ACTIVITY_NOT_FOUND));
        ReadableGroupAccess access = permissions.requireMutableMembership(a.getGroupId(), actor);
        if (!actor.equals(a.getCreatedBy()) && access.membership().getRole() != GroupRole.OWNER && access.membership().getRole() != GroupRole.ADMIN) {
            throw new BusinessException(ErrorCode.INSUFFICIENT_GROUP_PERMISSION);
        }
        return a;
    }

    private void transition(ActivityEntity a, ActivityStatus to, UUID actor, String reason) {
        Instant now = clock.instant();
        ActivityStatus from = a.getStatus();
        a.transitionTo(to, now);
        statusHistory.save(new ActivityStatusHistoryEntity(UUID.randomUUID(), a.getId(), from, to, actor, reason, now));
    }

    private ActivityStatus effective(ActivityEntity a, Instant n) {
        if (a.getEndAt() != null && !n.isBefore(a.getEndAt())) return ActivityStatus.COMPLETED;
        if (a.getStartAt() != null && !n.isBefore(a.getStartAt()) && a.getStatus() == ActivityStatus.CONFIRMED) return ActivityStatus.IN_PROGRESS;
        return a.getStatus();
    }

    private void validate(Instant s, Instant e, String z, Integer c) {
        if (c != null && c <= 0) throw new BusinessException(ErrorCode.ACTIVITY_CAPACITY_INVALID);
        if (s == null) {
            if (e != null || (z != null && !z.isBlank())) {
                throw new BusinessException(ErrorCode.INVALID_ACTIVITY_TIME);
            }
            return;
        }
        if (e != null && !e.isAfter(s)) throw new BusinessException(ErrorCode.INVALID_ACTIVITY_TIME);
        if (z == null || z.isBlank()) throw new BusinessException(ErrorCode.INVALID_ACTIVITY_TIME);
        try {
            ZoneId.of(z.trim());
        } catch (Exception x) {
            throw new BusinessException(ErrorCode.INVALID_ACTIVITY_TIME);
        }
    }

    private void logIfChanged(ActivityEntity a, UUID actor, String f, Object oldV, Object newV, Instant now) {
        if (!java.util.Objects.equals(oldV, newV)) {
            changes.save(new ActivityChangeLogEntity(UUID.randomUUID(), a.getId(), actor, f, String.valueOf(oldV), String.valueOf(newV), now));
        }
    }

    private ActivityDetailResponse response(ActivityEntity activity, UUID actor) {
        return responses.detail(activity, actor, permissions.requireReadableMembership(activity.getGroupId(), actor));
    }
}
