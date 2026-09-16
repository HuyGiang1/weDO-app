package com.wedo.backend.activity.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity @Table(name = "activity_rsvp_history")
public class ActivityRsvpHistoryEntity {
    @Id @Column(nullable=false) private UUID id;
    @Column(name="activity_id", nullable=false) private UUID activityId;
    @Column(name="user_id", nullable=false) private UUID userId;
    @Enumerated(EnumType.STRING) @Column(name="from_status", length=20) private ActivityRsvpStatus fromStatus;
    @Enumerated(EnumType.STRING) @Column(name="to_status", nullable=false, length=20) private ActivityRsvpStatus toStatus;
    @Column(name="changed_by") private UUID changedBy;
    @Column(name="created_at", nullable=false) private Instant createdAt;
    protected ActivityRsvpHistoryEntity() { }
    public ActivityRsvpHistoryEntity(UUID id, UUID activityId, UUID userId, ActivityRsvpStatus fromStatus, ActivityRsvpStatus toStatus, UUID changedBy, Instant createdAt) { this.id=id;this.activityId=activityId;this.userId=userId;this.fromStatus=fromStatus;this.toStatus=toStatus;this.changedBy=changedBy;this.createdAt=createdAt; }
    public UUID getId(){return id;} public UUID getActivityId(){return activityId;} public UUID getUserId(){return userId;} public ActivityRsvpStatus getFromStatus(){return fromStatus;} public ActivityRsvpStatus getToStatus(){return toStatus;} public UUID getChangedBy(){return changedBy;} public Instant getCreatedAt(){return createdAt;}
}
