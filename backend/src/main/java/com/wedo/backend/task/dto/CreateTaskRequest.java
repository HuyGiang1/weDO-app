package com.wedo.backend.task.dto;
import jakarta.validation.constraints.*; import java.time.Instant; import java.util.*;
public record CreateTaskRequest(@NotBlank @Size(max=255) String title,@Size(max=10000) String description,List<UUID> assigneeUserIds,Instant dueAt) { }
