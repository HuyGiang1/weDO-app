package com.wedo.backend.activity.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity @Table(name = "activity_status_history")
public class ActivityStatusHistoryEntity {
    @Id @Column(nullable=false) private UUID id;
    @Column(name="activity_id", nullable=false) private UUID activityId;
    @Enumerated(EnumType.STRING) @Column(name="from_status", length=20) private ActivityStatus fromStatus;
    @Enumerated(EnumType.STRING) @Column(name="to_status", nullable=false, length=20) private ActivityStatus toStatus;
    @Column(name="changed_by") private UUID changedBy;
    @Column(length=500) private String reason;
    @Column(name="created_at", nullable=false) private Instant createdAt;
    protected ActivityStatusHistoryEntity() { }
    public ActivityStatusHistoryEntity(UUID id, UUID activityId, ActivityStatus fromStatus, ActivityStatus toStatus, UUID changedBy, String reason, Instant createdAt) { this.id=id;this.activityId=activityId;this.fromStatus=fromStatus;this.toStatus=toStatus;this.changedBy=changedBy;this.reason=reason;this.createdAt=createdAt; }
    public UUID getId(){return id;} public UUID getActivityId(){return activityId;} public ActivityStatus getFromStatus(){return fromStatus;} public ActivityStatus getToStatus(){return toStatus;} public UUID getChangedBy(){return changedBy;} public String getReason(){return reason;} public Instant getCreatedAt(){return createdAt;}
}
