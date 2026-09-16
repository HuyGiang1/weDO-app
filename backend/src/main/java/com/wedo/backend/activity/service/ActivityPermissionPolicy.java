package com.wedo.backend.activity.service;

import com.wedo.backend.activity.dto.ActivityPermissionFlags;
import com.wedo.backend.activity.entity.ActivityEntity;
import com.wedo.backend.activity.entity.ActivityStatus;
import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.service.ReadableGroupAccess;
import java.time.Instant;

/** Single source for caller capabilities exposed in activity read DTOs. */
public final class ActivityPermissionPolicy {
    private ActivityPermissionPolicy() { }

    public static ActivityPermissionFlags forCaller(ActivityEntity activity, ReadableGroupAccess access,
                                                    java.util.UUID callerId, ActivityStatus effectiveStatus) {
        boolean manager = callerId.equals(activity.getCreatedBy())
                || access.membership().getRole() == GroupRole.OWNER
                || access.membership().getRole() == GroupRole.ADMIN;
        boolean closed = effectiveStatus == ActivityStatus.COMPLETED || effectiveStatus == ActivityStatus.CANCELLED;
        boolean editable = manager && !closed;
        boolean confirmable = manager && effectiveStatus == ActivityStatus.PLANNING;
        boolean cancellable = manager && (effectiveStatus == ActivityStatus.PLANNING || effectiveStatus == ActivityStatus.CONFIRMED);
        boolean completable = manager && activity.getEndAt() == null
                && (effectiveStatus == ActivityStatus.CONFIRMED || effectiveStatus == ActivityStatus.IN_PROGRESS);
        return new ActivityPermissionFlags(editable, confirmable, cancellable, completable, !closed);
    }
}
