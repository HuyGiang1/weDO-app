package com.wedo.backend.group.repository;

import com.wedo.backend.group.entity.GroupMembershipEntity;
import com.wedo.backend.group.entity.GroupMembershipStatus;
import com.wedo.backend.group.entity.GroupRole;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.jpa.repository.Lock;
import jakarta.persistence.LockModeType;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface GroupMembershipRepository extends JpaRepository<GroupMembershipEntity, UUID> {
    List<GroupMembershipEntity> findByGroupIdAndUserIdAndStatus(UUID groupId, UUID userId, GroupMembershipStatus status);

    Optional<GroupMembershipEntity> findFirstByGroupIdAndUserIdAndStatus(UUID groupId, UUID userId, GroupMembershipStatus status);

    Optional<GroupMembershipEntity> findFirstByGroupIdAndRoleAndStatus(UUID groupId, GroupRole role, GroupMembershipStatus status);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select m from GroupMembershipEntity m where m.groupId = :groupId and m.userId = :userId and m.status = :status")
    Optional<GroupMembershipEntity> findActiveByGroupIdAndUserIdForUpdate(@Param("groupId") UUID groupId, @Param("userId") UUID userId, @Param("status") GroupMembershipStatus status);

    @Query(value = """
            SELECT g.id AS id, g.name AS name, g.avatar_storage_key AS \"avatarStorageKey\",
                   g.status AS status, m.role AS \"callerRole\", g.updated_at AS \"updatedAt\"
            FROM group_memberships m
            JOIN groups g ON g.id = m.group_id
            WHERE m.user_id = :userId AND m.status = 'ACTIVE' AND g.status = :status
            ORDER BY g.updated_at DESC, g.id DESC
            """,
            countQuery = """
            SELECT COUNT(*)
            FROM group_memberships m
            JOIN groups g ON g.id = m.group_id
            WHERE m.user_id = :userId AND m.status = 'ACTIVE' AND g.status = :status
            """,
            nativeQuery = true)
    Page<GroupSummaryProjection> findGroupSummariesByActiveMember(
            @Param("userId") UUID userId,
            @Param("status") String status,
            Pageable pageable
    );

    @Query(value = """
            SELECT m.user_id AS \"userId\", u.username::text AS username, u.display_name AS \"displayName\",
                   u.avatar_storage_key AS \"avatarStorageKey\", m.role AS role, m.created_at AS \"joinedAt\"
            FROM group_memberships m
            JOIN users u ON u.id = m.user_id
            WHERE m.group_id = :groupId AND m.status = 'ACTIVE'
            ORDER BY m.created_at ASC, m.user_id ASC
            """, nativeQuery = true)
    List<GroupMemberProjection> findActiveMemberResponsesByGroupId(@Param("groupId") UUID groupId);

    @Query(value = """
            SELECT m.user_id AS \"userId\", u.username::text AS username, u.display_name AS \"displayName\",
                   u.avatar_storage_key AS \"avatarStorageKey\", m.role AS role, m.created_at AS \"joinedAt\"
            FROM group_memberships m
            JOIN users u ON u.id = m.user_id
            WHERE m.group_id = :groupId AND m.user_id = :userId AND m.status = 'ACTIVE'
            """, nativeQuery = true)
    Optional<GroupMemberProjection> findActiveMemberResponseByGroupIdAndUserId(
            @Param("groupId") UUID groupId,
            @Param("userId") UUID userId
    );

    long countByGroupIdAndStatus(UUID groupId, GroupMembershipStatus status);

    long countByGroupIdAndRoleAndStatus(UUID groupId, GroupRole role, GroupMembershipStatus status);
}
