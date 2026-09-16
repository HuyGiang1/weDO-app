package com.wedo.backend.activity.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "activities")
public class ActivityEntity {
    @Id @Column(nullable = false) private UUID id;
    @Column(name = "group_id", nullable = false) private UUID groupId;
    @Column(name = "created_by") private UUID createdBy;
    @Column(nullable = false, length = 200) private String title;
    @Column private String description;
    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 20) private ActivityStatus status;
    @Column(name = "start_at", nullable = false) private Instant startAt;
    @Column(name = "end_at") private Instant endAt;
    @Column(nullable = false, length = 50) private String timezone;
    @JdbcTypeCode(SqlTypes.JSON) @Column(columnDefinition = "jsonb") private ActivityLocation location;
    @Column(name = "capacity") private Integer capacity;
    @Column(name = "created_at", nullable = false) private Instant createdAt;
    @Column(name = "updated_at", nullable = false) private Instant updatedAt;

    protected ActivityEntity() { }
    public ActivityEntity(UUID id, UUID groupId, UUID createdBy, String title, String description, ActivityStatus status,
                          Instant startAt, Instant endAt, String timezone, ActivityLocation location, Integer capacity,
                          Instant createdAt, Instant updatedAt) {
        this.id = id; this.groupId = groupId; this.createdBy = createdBy; this.title = title; this.description = description;
        this.status = status; this.startAt = startAt; this.endAt = endAt; this.timezone = timezone; this.location = location;
        this.capacity = capacity; this.createdAt = createdAt; this.updatedAt = updatedAt;
    }
    public UUID getId() { return id; } public UUID getGroupId() { return groupId; } public UUID getCreatedBy() { return createdBy; }
    public String getTitle() { return title; } public String getDescription() { return description; } public ActivityStatus getStatus() { return status; }
    public Instant getStartAt() { return startAt; } public Instant getEndAt() { return endAt; } public String getTimezone() { return timezone; }
    public ActivityLocation getLocation() { return location; } public Integer getCapacity() { return capacity; }
    public Instant getCreatedAt() { return createdAt; } public Instant getUpdatedAt() { return updatedAt; }
    public void transitionTo(ActivityStatus next, Instant now) { this.status = next; this.updatedAt = now; }
    public void update(String title, String description, Instant startAt, Instant endAt, String timezone, ActivityLocation location, Integer capacity, Instant now) {
        this.title=title; this.description=description; this.startAt=startAt; this.endAt=endAt; this.timezone=timezone; this.location=location; this.capacity=capacity; this.updatedAt=now;
    }
}
