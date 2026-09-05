package com.wedo.backend.auth.repository;

import com.wedo.backend.auth.entity.AuthTokenEntity;
import com.wedo.backend.auth.entity.AuthTokenType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface AuthTokenRepository extends JpaRepository<AuthTokenEntity, UUID> {

    Optional<AuthTokenEntity> findFirstByUserIdAndTokenTypeAndConsumedAtIsNullOrderByCreatedAtDesc(
            UUID userId,
            AuthTokenType tokenType
    );

    Optional<AuthTokenEntity> findFirstByUserIdAndTokenTypeOrderByCreatedAtDesc(
            UUID userId,
            AuthTokenType tokenType
    );

    List<AuthTokenEntity> findAllByUserIdAndTokenTypeAndConsumedAtIsNull(
            UUID userId,
            AuthTokenType tokenType
    );

    List<AuthTokenEntity> findAllByUserIdAndTokenTypeAndConsumedAtIsNullOrderByCreatedAtDescIdDesc(
            UUID userId,
            AuthTokenType tokenType
    );

    boolean existsByUserIdAndTokenTypeAndTokenHashAndConsumedAtIsNotNull(
            UUID userId,
            AuthTokenType tokenType,
            String tokenHash
    );
}
