package com.wedo.backend.user.repository;

import com.wedo.backend.user.entity.UserPrivacySettingsEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface UserPrivacySettingsRepository extends JpaRepository<UserPrivacySettingsEntity, UUID> {
}
