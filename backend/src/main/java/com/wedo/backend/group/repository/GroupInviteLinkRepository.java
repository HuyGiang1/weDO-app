package com.wedo.backend.group.repository;

import com.wedo.backend.group.entity.GroupInviteLinkEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import jakarta.persistence.LockModeType;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface GroupInviteLinkRepository extends JpaRepository<GroupInviteLinkEntity, UUID> {

    Optional<GroupInviteLinkEntity> findByCode(String code);

    interface InviteLinkIdentity { UUID getId(); UUID getGroupId(); }

    @Query("select l.id as id, l.groupId as groupId from GroupInviteLinkEntity l where l.code=:code")
    Optional<InviteLinkIdentity> findIdentityByCode(String code);

    @Query("select l.id as id, l.groupId as groupId from GroupInviteLinkEntity l where l.id=:id")
    Optional<InviteLinkIdentity> findIdentityById(UUID id);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select l from GroupInviteLinkEntity l where l.id=:id")
    Optional<GroupInviteLinkEntity> findByIdForUpdate(UUID id);

    List<GroupInviteLinkEntity> findByGroupIdOrderByCreatedAtDesc(UUID groupId);

    Optional<GroupInviteLinkEntity> findByIdAndGroupId(UUID id, UUID groupId);
}
