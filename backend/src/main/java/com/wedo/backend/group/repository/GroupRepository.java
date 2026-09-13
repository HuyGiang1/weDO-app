package com.wedo.backend.group.repository;

import com.wedo.backend.group.entity.GroupEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface GroupRepository extends JpaRepository<GroupEntity, UUID> {
}
