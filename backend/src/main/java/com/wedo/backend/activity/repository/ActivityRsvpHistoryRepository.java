package com.wedo.backend.activity.repository;

import com.wedo.backend.activity.entity.ActivityRsvpHistoryEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.UUID;

public interface ActivityRsvpHistoryRepository extends JpaRepository<ActivityRsvpHistoryEntity, UUID> { }
