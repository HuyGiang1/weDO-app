package com.wedo.backend.user.repository;

import com.wedo.backend.user.entity.UserEntity;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface UserRepository extends JpaRepository<UserEntity, UUID> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT u FROM UserEntity u WHERE u.id = :id")
    Optional<UserEntity> findByIdWithLock(@Param("id") UUID id);

    @Query(value = "SELECT * FROM users WHERE email = CAST(:email AS citext)", nativeQuery = true)
    Optional<UserEntity> findByEmail(@Param("email") String email);

    @Query(value = "SELECT * FROM users WHERE username = CAST(:username AS citext)", nativeQuery = true)
    Optional<UserEntity> findByUsername(@Param("username") String username);

    @Query(value = "SELECT COUNT(*) > 0 FROM users WHERE email = CAST(:email AS citext)", nativeQuery = true)
    boolean existsByEmail(@Param("email") String email);

    @Query(value = "SELECT COUNT(*) > 0 FROM users WHERE username = CAST(:username AS citext)", nativeQuery = true)
    boolean existsByUsername(@Param("username") String username);
}
