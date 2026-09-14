package com.wedo.backend.group.repository;

import com.wedo.backend.group.entity.GroupActivityLogEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.util.List;
import java.util.UUID;

public interface GroupActivityLogRepository extends JpaRepository<GroupActivityLogEntity, UUID> {
    List<GroupActivityLogEntity> findByGroupId(UUID groupId);
    Page<GroupActivityLogEntity> findByGroupId(UUID groupId, Pageable pageable);
}
