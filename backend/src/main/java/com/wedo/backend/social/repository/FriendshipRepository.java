package com.wedo.backend.social.repository;

import com.wedo.backend.social.entity.FriendshipEntity;
import com.wedo.backend.social.entity.FriendshipStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface FriendshipRepository extends JpaRepository<FriendshipEntity, UUID> {

    @Query("SELECT f FROM FriendshipEntity f WHERE f.userId1 = :u1 AND f.userId2 = :u2 AND f.status = com.wedo.backend.social.entity.FriendshipStatus.ACTIVE")
    Optional<FriendshipEntity> findActiveByCanonicalPair(@Param("u1") UUID u1, @Param("u2") UUID u2);

    default Optional<FriendshipEntity> findActiveBetween(UUID userA, UUID userB) {
        UUID u1 = userA.compareTo(userB) < 0 ? userA : userB;
        UUID u2 = userA.compareTo(userB) < 0 ? userB : userA;
        return findActiveByCanonicalPair(u1, u2);
    }

    default boolean existsActiveBetween(UUID userA, UUID userB) {
        return findActiveBetween(userA, userB).isPresent();
    }

    @Query("SELECT f FROM FriendshipEntity f WHERE (f.userId1 = :userId OR f.userId2 = :userId) AND f.status = com.wedo.backend.social.entity.FriendshipStatus.ACTIVE ORDER BY f.createdAt DESC")
    Page<FriendshipEntity> findActiveFriendshipsByUser(@Param("userId") UUID userId, Pageable pageable);

    @Modifying
    @Query("UPDATE FriendshipEntity f SET f.status = com.wedo.backend.social.entity.FriendshipStatus.ENDED, f.endedAt = :now WHERE f.userId1 = :u1 AND f.userId2 = :u2 AND f.status = com.wedo.backend.social.entity.FriendshipStatus.ACTIVE")
    int endActiveFriendship(@Param("u1") UUID u1, @Param("u2") UUID u2, @Param("now") Instant now);

    default int endActiveFriendshipBetween(UUID userA, UUID userB, Instant now) {
        UUID u1 = userA.compareTo(userB) < 0 ? userA : userB;
        UUID u2 = userA.compareTo(userB) < 0 ? userB : userA;
        return endActiveFriendship(u1, u2, now);
    }
}
