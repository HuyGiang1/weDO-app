package com.wedo.backend.activity.reminder;

import com.wedo.backend.activity.entity.ActivityEntity;
import com.wedo.backend.activity.entity.ActivityStatus;
import com.wedo.backend.activity.service.M8ActivityAccessService;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.group.service.GroupPermissionService;
import com.wedo.backend.group.service.ReadableGroupAccess;
import java.time.Clock;
import java.time.Instant;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import static com.wedo.backend.activity.reminder.ActivityReminderDtos.Request;
import static com.wedo.backend.activity.reminder.ActivityReminderDtos.Response;

@Service
public class ActivityReminderService {
    private final ActivityReminderRepository reminders;
    private final M8ActivityAccessService activityAccess;
    private final GroupPermissionService groupPermissions;
    private final Clock clock;

    public ActivityReminderService(ActivityReminderRepository reminders,
                                   M8ActivityAccessService activityAccess,
                                   GroupPermissionService groupPermissions,
                                   Clock clock) {
        this.reminders = reminders;
        this.activityAccess = activityAccess;
        this.groupPermissions = groupPermissions;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public Response get(UUID activityId, UUID userId) {
        var access = activityAccess.requireReadable(activityId, userId);
        return reminders.findByActivityIdAndUserId(activityId, userId)
                .map(row -> response(access.activity(), access.groupAccess().group().getStatus(), row))
                .orElseGet(() -> empty(access.activity(), access.groupAccess().group().getStatus()));
    }

    @Transactional
    public Response put(UUID activityId, UUID userId, Request request) {
        var access = activityAccess.requireReadable(activityId, userId);
        ActivityEntity activity = activityAccess.requireLocked(activityId);
        Instant now = clock.instant();
        ActivityReminderEntity current = reminders.findByActivityIdAndUserIdForUpdate(activityId, userId).orElse(null);
        Integer offset = request.offsetMinutes() != null ? request.offsetMinutes()
                : current == null ? null : current.getOffsetMinutes();

        if (Boolean.TRUE.equals(request.enabled())) {
            groupPermissions.requireMutableMembership(activity.getGroupId(), userId);
            requireEligible(activity, now);
            requireOffset(offset);
        } else if (offset != null) {
            requireOffset(offset);
        }

        if (current == null) {
            if (offset == null || activity.getStartAt() == null) {
                return empty(activity, access.groupAccess().group().getStatus());
            }
            Instant remindAt = activity.getStartAt().minusSeconds(Math.multiplyExact(offset.longValue(), 60));
            current = new ActivityReminderEntity(UUID.randomUUID(), activityId, userId,
                    Boolean.TRUE.equals(request.enabled()), offset, remindAt, now);
            current = reminders.save(current);
        } else {
            int nextOffset = offset == null ? current.getOffsetMinutes() : offset;
            Instant remindAt = activity.getStartAt() == null ? current.getRemindAt()
                    : activity.getStartAt().minusSeconds(Math.multiplyExact((long) nextOffset, 60));
            boolean changedOffset = nextOffset != current.getOffsetMinutes();
            current.configure(Boolean.TRUE.equals(request.enabled()), nextOffset, remindAt,
                    current.getSentAt() != null && changedOffset, now);
        }
        return response(activity, access.groupAccess().group().getStatus(), current);
    }

    @Transactional
    public void rescheduleForActivity(UUID activityId, Instant newStartAt, Instant now) {
        if (newStartAt == null) return;
        for (ActivityReminderEntity reminder : reminders.findByActivityIdAndEnabledTrueAndSentAtIsNull(activityId)) {
            reminder.reschedule(newStartAt.minusSeconds(Math.multiplyExact((long) reminder.getOffsetMinutes(), 60)), now);
        }
    }

    private Response response(ActivityEntity activity, GroupStatus groupStatus, ActivityReminderEntity row) {
        Eligibility eligibility = eligibility(activity, groupStatus, clock.instant());
        return new Response(activity.getId(), true, row.isEnabled(), row.getOffsetMinutes(),
                row.getRemindAt(), row.getSentAt(), eligibility.allowed(), eligibility.reason());
    }

    private Response empty(ActivityEntity activity, GroupStatus groupStatus) {
        Eligibility eligibility = eligibility(activity, groupStatus, clock.instant());
        return new Response(activity.getId(), false, false, null, null, null,
                eligibility.allowed(), eligibility.reason());
    }

    private void requireEligible(ActivityEntity activity, Instant now) {
        Eligibility eligibility = eligibility(activity, GroupStatus.ACTIVE, now);
        if (!eligibility.allowed()) throw new BusinessException(ErrorCode.ACTIVITY_REMINDER_NOT_ALLOWED);
    }

    private Eligibility eligibility(ActivityEntity activity, GroupStatus groupStatus, Instant now) {
        if (groupStatus != GroupStatus.ACTIVE) return new Eligibility(false, "GROUP_ARCHIVED");
        if (activity.getStatus() == ActivityStatus.CANCELLED || activity.getStatus() == ActivityStatus.COMPLETED) {
            return new Eligibility(false, "ACTIVITY_TERMINAL");
        }
        if (activity.getStatus() == ActivityStatus.IN_PROGRESS) return new Eligibility(false, "ACTIVITY_IN_PROGRESS");
        if (activity.getStartAt() == null) return new Eligibility(false, "ACTIVITY_UNSCHEDULED");
        if (!activity.getStartAt().isAfter(now)) return new Eligibility(false, "ACTIVITY_ALREADY_STARTED");
        return new Eligibility(true, null);
    }

    private void requireOffset(Integer offset) {
        if (offset == null || offset <= 0) throw new BusinessException(ErrorCode.ACTIVITY_REMINDER_OFFSET_INVALID);
    }

    private record Eligibility(boolean allowed, String reason) { }
}
