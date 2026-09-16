package com.wedo.backend.activity.service;

import com.wedo.backend.activity.dto.ActivityParticipantResponse;
import com.wedo.backend.activity.entity.ActivityParticipantEntity;
import com.wedo.backend.activity.repository.ActivityParticipantRepository;
import com.wedo.backend.activity.repository.ActivityRepository;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.group.service.GroupPermissionService;
import com.wedo.backend.user.repository.UserRepository;
import java.util.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ActivityParticipantService {
    private final ActivityRepository activities; private final ActivityParticipantRepository participants; private final UserRepository users; private final GroupPermissionService permissions;
    public ActivityParticipantService(ActivityRepository activities,ActivityParticipantRepository participants,UserRepository users,GroupPermissionService permissions){this.activities=activities;this.participants=participants;this.users=users;this.permissions=permissions;}
    @Transactional(readOnly=true) public List<ActivityParticipantResponse> list(UUID activityId,UUID callerId){var a=activities.findById(activityId).orElseThrow(()->new BusinessException(ErrorCode.ACTIVITY_NOT_FOUND));permissions.requireReadableMembership(a.getGroupId(),callerId);return participants.findProjectionByActivityId(activityId).stream().map(this::map).toList();}
    private ActivityParticipantResponse map(ActivityParticipantEntity p){var u=users.findById(p.getUserId()).orElse(null);return new ActivityParticipantResponse(p.getUserId(),u==null?null:u.getDisplayName(),u==null?null:u.getUsername(),u==null?null:u.getAvatarStorageKey(),p.getRsvpStatus(),p.getWaitlistSequence(),p.getStatusUpdatedAt());}
}
