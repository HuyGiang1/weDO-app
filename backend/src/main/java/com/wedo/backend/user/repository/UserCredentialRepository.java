package com.wedo.backend.user.repository;

import com.wedo.backend.user.entity.UserCredentialEntity;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface UserCredentialRepository extends JpaRepository<UserCredentialEntity, UUID> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("""
        select c
        from UserCredentialEntity c
        where c.userId = :userId
    """)
    Optional<UserCredentialEntity> findByUserIdWithLock(@Param("userId") UUID userId);
}
