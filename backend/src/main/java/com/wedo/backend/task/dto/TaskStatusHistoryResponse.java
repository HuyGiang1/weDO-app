package com.wedo.backend.task.dto;
import com.wedo.backend.task.entity.TaskStatusHistoryEntity; import java.time.Instant; import java.util.UUID;
public record TaskStatusHistoryResponse(String fromStatus,String toStatus,UUID changedBy,Instant createdAt){public static TaskStatusHistoryResponse of(TaskStatusHistoryEntity e){return new TaskStatusHistoryResponse(e.getFromStatus()==null?null:e.getFromStatus().name(),e.getToStatus().name(),e.getChangedBy(),e.getCreatedAt());}}
