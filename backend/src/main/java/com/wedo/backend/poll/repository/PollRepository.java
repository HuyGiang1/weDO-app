package com.wedo.backend.poll.repository;
import com.wedo.backend.poll.entity.PollEntity; import jakarta.persistence.LockModeType; import org.springframework.data.jpa.repository.*; import java.util.*;
public interface PollRepository extends JpaRepository<PollEntity,UUID> { List<PollEntity> findByActivityIdOrderByCreatedAtDesc(UUID activityId); @Lock(LockModeType.PESSIMISTIC_WRITE) @Query("select p from PollEntity p where p.id=:id") Optional<PollEntity> findByIdForUpdate(UUID id); }
