package com.wedo.backend.activity.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity @Table(name = "activity_change_logs")
public class ActivityChangeLogEntity {
    @Id @Column(nullable=false) private UUID id;
    @Column(name="activity_id", nullable=false) private UUID activityId;
    @Column(name="actor_id") private UUID actorId;
    @Column(name="field_name", nullable=false, length=50) private String fieldName;
    @Column(name="old_value") private String oldValue;
    @Column(name="new_value") private String newValue;
    @Column(name="created_at", nullable=false) private Instant createdAt;
    protected ActivityChangeLogEntity() { }
    public ActivityChangeLogEntity(UUID id, UUID activityId, UUID actorId, String fieldName, String oldValue, String newValue, Instant createdAt) { this.id=id;this.activityId=activityId;this.actorId=actorId;this.fieldName=fieldName;this.oldValue=oldValue;this.newValue=newValue;this.createdAt=createdAt; }
    public UUID getId(){return id;} public UUID getActivityId(){return activityId;} public UUID getActorId(){return actorId;} public String getFieldName(){return fieldName;} public String getOldValue(){return oldValue;} public String getNewValue(){return newValue;} public Instant getCreatedAt(){return createdAt;}
}
