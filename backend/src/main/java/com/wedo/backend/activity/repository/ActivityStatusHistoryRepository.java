package com.wedo.backend.activity.repository;

import com.wedo.backend.activity.entity.ActivityStatusHistoryEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.UUID;

public interface ActivityStatusHistoryRepository extends JpaRepository<ActivityStatusHistoryEntity, UUID> { }
