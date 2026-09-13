package com.wedo.backend.group.repository;

import com.wedo.backend.group.entity.GroupMembershipEntity;
import com.wedo.backend.group.entity.GroupMembershipStatus;
import com.wedo.backend.group.entity.GroupRole;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface GroupMembershipRepository extends JpaRepository<GroupMembershipEntity, UUID> {
    List<GroupMembershipEntity> findByGroupIdAndUserIdAndStatus(UUID groupId, UUID userId, GroupMembershipStatus status);

    long countByGroupIdAndStatus(UUID groupId, GroupMembershipStatus status);

    long countByGroupIdAndRoleAndStatus(UUID groupId, GroupRole role, GroupMembershipStatus status);
}
