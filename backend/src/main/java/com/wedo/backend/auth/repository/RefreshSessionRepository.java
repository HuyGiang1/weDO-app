package com.wedo.backend.auth.repository;

import com.wedo.backend.auth.entity.RefreshSessionEntity;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface RefreshSessionRepository extends JpaRepository<RefreshSessionEntity, UUID> {

    Optional<RefreshSessionEntity> findByTokenHash(String tokenHash);

    @Query("""
        select r.userId
        from RefreshSessionEntity r
        where r.tokenHash = :tokenHash
    """)
    Optional<UUID> findUserIdByTokenHash(@Param("tokenHash") String tokenHash);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("""
        select r
        from RefreshSessionEntity r
        where r.tokenHash = :tokenHash
    """)
    Optional<RefreshSessionEntity> findByTokenHashWithLock(
        @Param("tokenHash") String tokenHash
    );

    @Modifying
    @Query("""
        update RefreshSessionEntity r
        set r.revokedAt = :revokedAt
        where r.userId = :userId
          and r.revokedAt is null
    """)
    int revokeAllActiveByUserId(
        @Param("userId") UUID userId,
        @Param("revokedAt") Instant revokedAt
    );
}
