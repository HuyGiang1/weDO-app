package com.wedo.backend.task.dto;
import jakarta.validation.constraints.*; import java.time.Instant; import java.util.*;
public record UpdateTaskRequest(@NotBlank @Size(max=255) String title,@Size(max=10000) String description,Instant dueAt,List<UUID> assigneeUserIds) { }
