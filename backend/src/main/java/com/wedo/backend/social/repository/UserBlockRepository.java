package com.wedo.backend.social.repository;

import com.wedo.backend.social.entity.UserBlockEntity;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface UserBlockRepository extends JpaRepository<UserBlockEntity, UUID> {

    @Query("SELECT COUNT(ub) > 0 FROM UserBlockEntity ub WHERE (ub.blockerId = :userA AND ub.blockedId = :userB) OR (ub.blockerId = :userB AND ub.blockedId = :userA)")
    boolean existsBlockBetween(@Param("userA") UUID userA, @Param("userB") UUID userB);

    boolean existsByBlockerIdAndBlockedId(UUID blockerId, UUID blockedId);

    Optional<UserBlockEntity> findByBlockerIdAndBlockedId(UUID blockerId, UUID blockedId);

    Page<UserBlockEntity> findByBlockerIdOrderByCreatedAtDesc(UUID blockerId, Pageable pageable);

    @Modifying
    @Query("DELETE FROM UserBlockEntity ub WHERE ub.blockerId = :blockerId AND ub.blockedId = :blockedId")
    int deleteByBlockerIdAndBlockedId(@Param("blockerId") UUID blockerId, @Param("blockedId") UUID blockedId);
}
