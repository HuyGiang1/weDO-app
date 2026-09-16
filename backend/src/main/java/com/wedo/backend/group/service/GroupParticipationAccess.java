package com.wedo.backend.group.service;

import com.wedo.backend.group.entity.GroupEntity;
import com.wedo.backend.group.entity.GroupMembershipEntity;

public record GroupParticipationAccess(GroupEntity group, GroupMembershipEntity membership) { }
