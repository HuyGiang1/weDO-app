package com.wedo.backend.social.repository;

import com.wedo.backend.social.entity.FriendRequestEntity;
import com.wedo.backend.social.entity.FriendRequestStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface FriendRequestRepository extends JpaRepository<FriendRequestEntity, UUID> {

    @Query("SELECT COUNT(fr) > 0 FROM FriendRequestEntity fr WHERE ((fr.senderId = :userA AND fr.receiverId = :userB) OR (fr.senderId = :userB AND fr.receiverId = :userA)) AND fr.status = com.wedo.backend.social.entity.FriendRequestStatus.PENDING")
    boolean existsPendingBetween(@Param("userA") UUID userA, @Param("userB") UUID userB);

    @Query("SELECT fr FROM FriendRequestEntity fr WHERE ((fr.senderId = :userA AND fr.receiverId = :userB) OR (fr.senderId = :userB AND fr.receiverId = :userA)) AND fr.status = com.wedo.backend.social.entity.FriendRequestStatus.PENDING")
    Optional<FriendRequestEntity> findPendingBetween(@Param("userA") UUID userA, @Param("userB") UUID userB);

    @Query("SELECT fr FROM FriendRequestEntity fr WHERE fr.senderId = :senderId AND fr.receiverId = :receiverId AND fr.status = com.wedo.backend.social.entity.FriendRequestStatus.DECLINED ORDER BY fr.respondedAt DESC")
    List<FriendRequestEntity> findDeclinedRequests(@Param("senderId") UUID senderId, @Param("receiverId") UUID receiverId);

    Page<FriendRequestEntity> findByReceiverIdAndStatusOrderByCreatedAtDesc(UUID receiverId, FriendRequestStatus status, Pageable pageable);

    Page<FriendRequestEntity> findBySenderIdAndStatusOrderByCreatedAtDesc(UUID senderId, FriendRequestStatus status, Pageable pageable);

    @Modifying
    @Query("UPDATE FriendRequestEntity fr SET fr.status = :newStatus, fr.respondedAt = :now WHERE fr.id = :id AND fr.status = :expectedStatus")
    int updateStatusAtomically(@Param("id") UUID id, @Param("expectedStatus") FriendRequestStatus expectedStatus, @Param("newStatus") FriendRequestStatus newStatus, @Param("now") Instant now);

    @Modifying
    @Query("UPDATE FriendRequestEntity fr SET fr.status = com.wedo.backend.social.entity.FriendRequestStatus.CANCELLED, fr.respondedAt = :now WHERE ((fr.senderId = :userA AND fr.receiverId = :userB) OR (fr.senderId = :userB AND fr.receiverId = :userA)) AND fr.status = com.wedo.backend.social.entity.FriendRequestStatus.PENDING")
    int cancelPendingBetween(@Param("userA") UUID userA, @Param("userB") UUID userB, @Param("now") Instant now);
}
