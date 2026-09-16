package com.wedo.backend.activity.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity @Table(name = "activity_participants")
public class ActivityParticipantEntity {
    @Id @Column(nullable = false) private UUID id;
    @Column(name = "activity_id", nullable = false) private UUID activityId;
    @Column(name = "user_id", nullable = false) private UUID userId;
    @Enumerated(EnumType.STRING) @Column(name = "rsvp_status", nullable = false, length = 20) private ActivityRsvpStatus rsvpStatus;
    @Column(name = "waitlist_sequence") private Long waitlistSequence;
    @Column(name = "status_updated_at") private Instant statusUpdatedAt;
    @Column(name = "created_at", nullable = false) private Instant createdAt;
    @Column(name = "updated_at", nullable = false) private Instant updatedAt;
    protected ActivityParticipantEntity() { }
    public ActivityParticipantEntity(UUID id, UUID activityId, UUID userId, ActivityRsvpStatus rsvpStatus, Long waitlistSequence, Instant statusUpdatedAt, Instant createdAt, Instant updatedAt) {
        this.id=id; this.activityId=activityId; this.userId=userId; this.rsvpStatus=rsvpStatus; this.waitlistSequence=waitlistSequence; this.statusUpdatedAt=statusUpdatedAt; this.createdAt=createdAt; this.updatedAt=updatedAt;
    }
    public UUID getId(){return id;} public UUID getActivityId(){return activityId;} public UUID getUserId(){return userId;}
    public ActivityRsvpStatus getRsvpStatus(){return rsvpStatus;} public Long getWaitlistSequence(){return waitlistSequence;}
    public Instant getStatusUpdatedAt(){return statusUpdatedAt;} public Instant getCreatedAt(){return createdAt;} public Instant getUpdatedAt(){return updatedAt;}
    public void changeTo(ActivityRsvpStatus next, Long sequence, Instant now) { this.rsvpStatus=next; this.waitlistSequence=sequence; this.statusUpdatedAt=next == ActivityRsvpStatus.NO_RESPONSE ? null : now; this.updatedAt=now; }
}
