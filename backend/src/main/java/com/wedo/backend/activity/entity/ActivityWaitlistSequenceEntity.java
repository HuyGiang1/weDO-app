package com.wedo.backend.activity.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity @Table(name = "activity_waitlist_sequences")
public class ActivityWaitlistSequenceEntity {
    @Id @Column(name = "activity_id", nullable = false) private UUID activityId;
    @Column(name = "current_sequence", nullable = false) private long currentSequence;
    @Column(name = "updated_at", nullable = false) private Instant updatedAt;
    protected ActivityWaitlistSequenceEntity() { }
    public ActivityWaitlistSequenceEntity(UUID activityId, long currentSequence, Instant updatedAt) { this.activityId=activityId; this.currentSequence=currentSequence; this.updatedAt=updatedAt; }
    public UUID getActivityId(){return activityId;} public long getCurrentSequence(){return currentSequence;} public Instant getUpdatedAt(){return updatedAt;}
    public long next(Instant now) { currentSequence++; updatedAt=now; return currentSequence; }
}
