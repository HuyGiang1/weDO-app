package com.wedo.backend.activity.repository;

import com.wedo.backend.activity.entity.ActivityChangeLogEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.UUID;

public interface ActivityChangeLogRepository extends JpaRepository<ActivityChangeLogEntity, UUID> { }
