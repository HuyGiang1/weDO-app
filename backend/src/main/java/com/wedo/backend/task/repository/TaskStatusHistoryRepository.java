package com.wedo.backend.task.repository;
import com.wedo.backend.task.entity.TaskStatusHistoryEntity; import org.springframework.data.jpa.repository.JpaRepository; import java.util.*;
public interface TaskStatusHistoryRepository extends JpaRepository<TaskStatusHistoryEntity,UUID> { List<TaskStatusHistoryEntity> findByTaskIdOrderByCreatedAtAsc(UUID taskId); }
