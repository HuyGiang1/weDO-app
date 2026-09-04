package com.wedo.backend.user.repository;

import com.wedo.backend.user.entity.UserCredentialEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface UserCredentialRepository extends JpaRepository<UserCredentialEntity, UUID> {
}
