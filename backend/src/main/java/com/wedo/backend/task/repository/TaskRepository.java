package com.wedo.backend.task.repository;
import com.wedo.backend.task.entity.TaskEntity; import jakarta.persistence.LockModeType; import org.springframework.data.jpa.repository.*; import java.util.*;
public interface TaskRepository extends JpaRepository<TaskEntity,UUID> { List<TaskEntity> findByActivityIdOrderByCreatedAtDesc(UUID activityId); @Lock(LockModeType.PESSIMISTIC_WRITE) @Query("select t from TaskEntity t where t.id=:id") Optional<TaskEntity> findByIdForUpdate(UUID id); }
