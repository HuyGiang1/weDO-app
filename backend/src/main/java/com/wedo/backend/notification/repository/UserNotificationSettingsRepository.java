package com.wedo.backend.notification.repository;

import com.wedo.backend.notification.entity.UserNotificationSettingsEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface UserNotificationSettingsRepository extends JpaRepository<UserNotificationSettingsEntity, UUID> {
}
