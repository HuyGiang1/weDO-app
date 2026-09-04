package com.wedo.backend.user.repository;

import com.wedo.backend.user.entity.UserEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface UserRepository extends JpaRepository<UserEntity, UUID> {

    @org.springframework.data.jpa.repository.Query(value = "SELECT * FROM users WHERE email = CAST(:email AS citext)", nativeQuery = true)
    Optional<UserEntity> findByEmail(@org.springframework.data.repository.query.Param("email") String email);

    @org.springframework.data.jpa.repository.Query(value = "SELECT * FROM users WHERE username = CAST(:username AS citext)", nativeQuery = true)
    Optional<UserEntity> findByUsername(@org.springframework.data.repository.query.Param("username") String username);

    @org.springframework.data.jpa.repository.Query(value = "SELECT COUNT(*) > 0 FROM users WHERE email = CAST(:email AS citext)", nativeQuery = true)
    boolean existsByEmail(@org.springframework.data.repository.query.Param("email") String email);

    @org.springframework.data.jpa.repository.Query(value = "SELECT COUNT(*) > 0 FROM users WHERE username = CAST(:username AS citext)", nativeQuery = true)
    boolean existsByUsername(@org.springframework.data.repository.query.Param("username") String username);
}
