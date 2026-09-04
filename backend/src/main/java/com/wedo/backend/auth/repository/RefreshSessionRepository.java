package com.wedo.backend.auth.repository;

import com.wedo.backend.auth.entity.RefreshSessionEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface RefreshSessionRepository extends JpaRepository<RefreshSessionEntity, UUID> {

    Optional<RefreshSessionEntity> findByTokenHash(String tokenHash);
}
