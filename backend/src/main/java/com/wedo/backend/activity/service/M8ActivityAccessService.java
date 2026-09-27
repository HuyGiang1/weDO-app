package com.wedo.backend.activity.service;

import com.wedo.backend.activity.entity.ActivityEntity;
import com.wedo.backend.activity.repository.ActivityRepository;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.group.service.GroupPermissionService;
import org.springframework.stereotype.Service;
import java.util.UUID;

@Service
public class M8ActivityAccessService {
    private final ActivityRepository activities;
    private final GroupPermissionService groups;
    public M8ActivityAccessService(ActivityRepository activities, GroupPermissionService groups) { this.activities = activities; this.groups = groups; }
    public M8ActivityAccess requireReadable(UUID activityId, UUID userId) {
        ActivityEntity activity = activities.findById(activityId).orElseThrow(() -> new BusinessException(ErrorCode.ACTIVITY_NOT_FOUND));
        return new M8ActivityAccess(activity, groups.requireReadableMembership(activity.getGroupId(), userId));
    }
    public M8ActivityAccess requireMutable(UUID activityId, UUID userId) {
        ActivityEntity activity = activities.findById(activityId).orElseThrow(() -> new BusinessException(ErrorCode.ACTIVITY_NOT_FOUND));
        return new M8ActivityAccess(activity, groups.requireMutableMembership(activity.getGroupId(), userId));
    }
    public ActivityEntity requireLocked(UUID activityId) { return activities.findByIdForUpdate(activityId).orElseThrow(() -> new BusinessException(ErrorCode.ACTIVITY_NOT_FOUND)); }
}
