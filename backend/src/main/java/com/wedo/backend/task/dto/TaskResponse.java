package com.wedo.backend.task.dto;
import com.wedo.backend.task.entity.*; import java.time.Instant; import java.util.*;
public record TaskResponse(UUID id,UUID activityId,UUID createdBy,String title,String description,TaskStatus status,Instant dueAt,List<UUID> assigneeUserIds,List<TaskStatusHistoryResponse> statusHistory,TaskPermissions permissions){ }
