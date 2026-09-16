package com.wedo.backend.activity.repository;

import com.wedo.backend.activity.entity.ActivityParticipantEntity;
import com.wedo.backend.activity.entity.ActivityRsvpStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import jakarta.persistence.LockModeType;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ActivityParticipantRepository extends JpaRepository<ActivityParticipantEntity, UUID> {
    Optional<ActivityParticipantEntity> findByActivityIdAndUserId(UUID activityId, UUID userId);
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select p from ActivityParticipantEntity p where p.activityId=:activityId and p.userId=:userId")
    Optional<ActivityParticipantEntity> findByActivityIdAndUserIdForUpdate(UUID activityId, UUID userId);
    long countByActivityIdAndRsvpStatus(UUID activityId, ActivityRsvpStatus rsvpStatus);
    List<ActivityParticipantEntity> findByActivityIdAndRsvpStatusOrderByWaitlistSequenceAsc(UUID activityId, ActivityRsvpStatus rsvpStatus);
    @Query("select p from ActivityParticipantEntity p where p.activityId=:activityId " +
           "order by case p.rsvpStatus when 'GOING' then 0 when 'WAITLIST' then 1 when 'MAYBE' then 2 when 'NOT_GOING' then 3 else 4 end, " +
           "p.waitlistSequence asc nulls last, p.userId asc")
    List<ActivityParticipantEntity> findProjectionByActivityId(UUID activityId);
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    Optional<ActivityParticipantEntity> findFirstByActivityIdAndRsvpStatusOrderByWaitlistSequenceAsc(UUID activityId, ActivityRsvpStatus rsvpStatus);
    @Query("select p.activityId from ActivityParticipantEntity p join ActivityEntity a on a.id=p.activityId where a.groupId=:groupId and p.userId=:userId and a.status not in ('COMPLETED','CANCELLED') order by p.activityId asc")
    List<UUID> findOpenActivityIdsByGroupIdAndUserId(UUID groupId, UUID userId);
}
