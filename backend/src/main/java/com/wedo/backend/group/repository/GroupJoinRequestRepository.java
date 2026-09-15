package com.wedo.backend.group.repository;

import com.wedo.backend.group.entity.GroupJoinRequestEntity;
import com.wedo.backend.group.entity.GroupJoinRequestStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface GroupJoinRequestRepository extends JpaRepository<GroupJoinRequestEntity, UUID> {

    Optional<GroupJoinRequestEntity> findByGroupIdAndUserIdAndStatus(UUID groupId, UUID userId, GroupJoinRequestStatus status);

    boolean existsByGroupIdAndUserIdAndStatus(UUID groupId, UUID userId, GroupJoinRequestStatus status);

    Page<GroupJoinRequestEntity> findByGroupIdAndStatus(UUID groupId, GroupJoinRequestStatus status, Pageable pageable);

    List<GroupJoinRequestEntity> findByGroupIdAndUserId(UUID groupId, UUID userId);
}
