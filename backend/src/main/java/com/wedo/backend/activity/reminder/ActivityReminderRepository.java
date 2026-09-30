package com.wedo.backend.activity.reminder;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import jakarta.persistence.LockModeType;

public interface ActivityReminderRepository extends JpaRepository<ActivityReminderEntity, UUID> {
    Optional<ActivityReminderEntity> findByActivityIdAndUserId(UUID activityId, UUID userId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select r from ActivityReminderEntity r where r.activityId = :activityId and r.userId = :userId")
    Optional<ActivityReminderEntity> findByActivityIdAndUserIdForUpdate(
            @Param("activityId") UUID activityId,
            @Param("userId") UUID userId
    );

    @Query(value = """
            select * from user_activity_reminders
            where id = :reminderId
              and activity_id = :activityId
              and enabled = true
              and sent_at is null
              and remind_at <= :now
            for update skip locked
            """, nativeQuery = true)
    Optional<ActivityReminderEntity> tryFindDueByIdForUpdateSkipLocked(
            @Param("reminderId") UUID reminderId,
            @Param("activityId") UUID activityId,
            @Param("now") java.time.Instant now
    );

    List<ActivityReminderEntity> findByActivityIdAndEnabledTrueAndSentAtIsNull(UUID activityId);
}
