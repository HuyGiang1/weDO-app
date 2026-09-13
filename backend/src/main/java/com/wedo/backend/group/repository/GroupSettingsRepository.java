package com.wedo.backend.group.repository;

import com.wedo.backend.group.entity.GroupSettingsEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface GroupSettingsRepository extends JpaRepository<GroupSettingsEntity, UUID> {
}
