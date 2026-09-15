package com.wedo.backend.group.repository;

import com.wedo.backend.group.entity.GroupInvitationEntity;
import com.wedo.backend.group.entity.GroupInvitationStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface GroupInvitationRepository extends JpaRepository<GroupInvitationEntity, UUID> {

    Optional<GroupInvitationEntity> findByGroupIdAndInviteeIdAndStatus(UUID groupId, UUID inviteeId, GroupInvitationStatus status);

    boolean existsByGroupIdAndInviteeIdAndStatus(UUID groupId, UUID inviteeId, GroupInvitationStatus status);

    Page<GroupInvitationEntity> findByInviteeIdAndStatus(UUID inviteeId, GroupInvitationStatus status, Pageable pageable);

    List<GroupInvitationEntity> findByGroupIdAndInviteeId(UUID groupId, UUID inviteeId);
}
