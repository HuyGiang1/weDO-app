package com.wedo.backend.activity.service;

import com.wedo.backend.activity.entity.ActivityEntity;
import com.wedo.backend.group.service.ReadableGroupAccess;

public record M8ActivityAccess(ActivityEntity activity, ReadableGroupAccess groupAccess) { }
