package com.wedo.backend.activity.service;

import com.wedo.backend.activity.dto.ActivityDetailResponse;
import com.wedo.backend.activity.dto.ActivityCreatorResponse;
import com.wedo.backend.activity.dto.ActivityPermissionFlags;
import com.wedo.backend.activity.dto.ActivitySummaryResponse;
import com.wedo.backend.activity.entity.ActivityEntity;
import com.wedo.backend.activity.entity.ActivityRsvpStatus;

public final class ActivityMapper {
    private ActivityMapper() { }
    public static ActivitySummaryResponse toSummary(ActivityEntity activity) {
        return new ActivitySummaryResponse(activity.getId(), activity.getTitle(), activity.getStatus(), activity.getStartAt(), activity.getEndAt(), activity.getTimezone(), activity.getLocation() == null ? null : activity.getLocation().name(), activity.getCapacity(), 0, 0, ActivityRsvpStatus.NO_RESPONSE);
    }
    public static ActivityDetailResponse toDetail(ActivityEntity activity) {
        return new ActivityDetailResponse(activity.getId(), activity.getGroupId(), activity.getTitle(), activity.getDescription(), activity.getStatus(), activity.getStartAt(), activity.getEndAt(), activity.getTimezone(), activity.getLocation() == null ? null : activity.getLocation().toDto(), activity.getCapacity(), activity.getCreatedAt(), activity.getUpdatedAt(), new ActivityCreatorResponse(activity.getCreatedBy(), null, null, null), ActivityRsvpStatus.NO_RESPONSE, null, 0, 0, 0, 0, new ActivityPermissionFlags(false, false, false, false, false));
    }
}
