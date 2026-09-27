package com.wedo.backend.task.dto;
import com.wedo.backend.task.entity.TaskStatus; import jakarta.validation.constraints.NotNull; public record UpdateTaskStatusRequest(@NotNull TaskStatus status) { }
