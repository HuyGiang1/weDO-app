package com.wedo.backend.activity.repository;

import com.wedo.backend.activity.entity.ActivityEntity;
import jakarta.persistence.LockModeType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.Optional;
import java.util.UUID;

public interface ActivityRepository extends JpaRepository<ActivityEntity, UUID> {
    Page<ActivityEntity> findByGroupIdOrderByStartAtAsc(UUID groupId, Pageable pageable);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select a from ActivityEntity a where a.id = :activityId")
    Optional<ActivityEntity> findByIdForUpdate(UUID activityId);

    @Query(value = "select * from activities where id = :activityId for update skip locked", nativeQuery = true)
    Optional<ActivityEntity> tryFindByIdForUpdateSkipLocked(@Param("activityId") UUID activityId);
}
