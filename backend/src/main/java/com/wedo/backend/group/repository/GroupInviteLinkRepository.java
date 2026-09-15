package com.wedo.backend.group.repository;

import com.wedo.backend.group.entity.GroupInviteLinkEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface GroupInviteLinkRepository extends JpaRepository<GroupInviteLinkEntity, UUID> {

    Optional<GroupInviteLinkEntity> findByCode(String code);

    List<GroupInviteLinkEntity> findByGroupIdOrderByCreatedAtDesc(UUID groupId);

    Optional<GroupInviteLinkEntity> findByIdAndGroupId(UUID id, UUID groupId);
}
