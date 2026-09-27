package com.wedo.backend.task.repository;
import com.wedo.backend.task.entity.TaskAssigneeEntity; import org.springframework.data.jpa.repository.*; import java.util.*;
public interface TaskAssigneeRepository extends JpaRepository<TaskAssigneeEntity,UUID> { List<TaskAssigneeEntity> findByTaskId(UUID taskId); boolean existsByTaskIdAndUserId(UUID taskId,UUID userId); void deleteByTaskIdAndUserId(UUID taskId,UUID userId); long countByTaskId(UUID taskId); }
