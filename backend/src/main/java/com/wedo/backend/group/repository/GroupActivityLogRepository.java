package com.wedo.backend.group.repository;

import com.wedo.backend.group.entity.GroupActivityLogEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface GroupActivityLogRepository extends JpaRepository<GroupActivityLogEntity, UUID> {
    List<GroupActivityLogEntity> findByGroupId(UUID groupId);
}
