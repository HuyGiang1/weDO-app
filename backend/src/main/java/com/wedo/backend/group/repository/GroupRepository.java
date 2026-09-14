package com.wedo.backend.group.repository;

import com.wedo.backend.group.entity.GroupEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import jakarta.persistence.LockModeType;
import java.util.Optional;

import java.util.UUID;

public interface GroupRepository extends JpaRepository<GroupEntity, UUID> {
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select g from GroupEntity g where g.id = :groupId")
    Optional<GroupEntity> findByIdForUpdate(UUID groupId);
}
