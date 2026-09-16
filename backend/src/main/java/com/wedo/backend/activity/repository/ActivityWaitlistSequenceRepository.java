package com.wedo.backend.activity.repository;

import com.wedo.backend.activity.entity.ActivityWaitlistSequenceEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import jakarta.persistence.LockModeType;
import java.util.Optional;
import java.util.UUID;

public interface ActivityWaitlistSequenceRepository extends JpaRepository<ActivityWaitlistSequenceEntity, UUID> {
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select s from ActivityWaitlistSequenceEntity s where s.activityId=:activityId")
    Optional<ActivityWaitlistSequenceEntity> findByActivityIdForUpdate(UUID activityId);
}
