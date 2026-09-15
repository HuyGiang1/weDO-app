package com.wedo.backend.group.repository;

import com.wedo.backend.group.entity.GroupBanEntity;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface GroupBanRepository extends JpaRepository<GroupBanEntity, UUID> {

    Optional<GroupBanEntity> findByGroupIdAndUserIdAndUnbannedAtIsNull(UUID groupId, UUID userId);

    boolean existsByGroupIdAndUserIdAndUnbannedAtIsNull(UUID groupId, UUID userId);

    Page<GroupBanEntity> findByGroupIdAndUnbannedAtIsNullOrderByCreatedAtDesc(UUID groupId, Pageable pageable);
}
