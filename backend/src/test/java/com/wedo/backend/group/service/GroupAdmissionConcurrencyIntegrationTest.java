package com.wedo.backend.group.service;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.group.dto.CreateInvitationRequest;
import com.wedo.backend.group.dto.CreateInviteLinkRequest;
import com.wedo.backend.group.dto.GroupInvitationResponse;
import com.wedo.backend.group.dto.InviteLinkResponse;
import com.wedo.backend.group.dto.JoinRequestResponse;
import com.wedo.backend.group.entity.GroupEntity;
import com.wedo.backend.group.entity.GroupInvitationEntity;
import com.wedo.backend.group.entity.GroupInvitationStatus;
import com.wedo.backend.group.entity.GroupInviteLinkEntity;
import com.wedo.backend.group.entity.GroupJoinPolicy;
import com.wedo.backend.group.entity.GroupJoinRequestEntity;
import com.wedo.backend.group.entity.GroupJoinRequestStatus;
import com.wedo.backend.group.entity.GroupMembershipEntity;
import com.wedo.backend.group.entity.GroupMembershipStatus;
import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.entity.GroupSettingsEntity;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.group.repository.GroupActivityLogRepository;
import com.wedo.backend.group.repository.GroupBanRepository;
import com.wedo.backend.group.repository.GroupInvitationRepository;
import com.wedo.backend.group.repository.GroupInviteLinkRepository;
import com.wedo.backend.group.repository.GroupJoinRequestRepository;
import com.wedo.backend.group.repository.GroupMembershipRepository;
import com.wedo.backend.group.repository.GroupRepository;
import com.wedo.backend.group.repository.GroupSettingsRepository;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.*;

class GroupAdmissionConcurrencyIntegrationTest extends AbstractPostgresIntegrationTest {

    private static final Instant NOW = Instant.parse("2026-09-15T12:00:00Z");

    @Autowired private GroupAdmissionService admissionService;
    @Autowired private GroupRepository groupRepository;
    @Autowired private GroupSettingsRepository groupSettingsRepository;
    @Autowired private GroupMembershipRepository groupMembershipRepository;
    @Autowired private GroupInvitationRepository groupInvitationRepository;
    @Autowired private GroupInviteLinkRepository groupInviteLinkRepository;
    @Autowired private GroupJoinRequestRepository groupJoinRequestRepository;
    @Autowired private GroupBanRepository groupBanRepository;
    @Autowired private UserRepository userRepository;

    @Test
    void case1_ninetyEightActiveMembers_tenConcurrentAdmissions_exactlyTwoSucceedAndTotalIs100() throws Exception {
        UUID ownerId = createUser();
        UUID groupId = createGroup(ownerId);

        // Pre-fill 97 members (total with owner = 98)
        for (int i = 0; i < 97; i++) {
            UUID memberId = createUser();
            addMembership(groupId, memberId, GroupRole.MEMBER, GroupMembershipStatus.ACTIVE);
        }
        assertEquals(98, groupMembershipRepository.countByGroupIdAndStatus(groupId, GroupMembershipStatus.ACTIVE));

        // Create 10 invitations for 10 distinct users
        List<UUID> candidateUsers = new ArrayList<>();
        List<UUID> invitationIds = new ArrayList<>();
        for (int i = 0; i < 10; i++) {
            UUID candidateId = createUser();
            candidateUsers.add(candidateId);
            GroupInvitationEntity inv = groupInvitationRepository.save(new GroupInvitationEntity(
                    UUID.randomUUID(), groupId, ownerId, candidateId, GroupInvitationStatus.PENDING, NOW, null
            ));
            invitationIds.add(inv.getId());
        }

        // Run 10 concurrent accept attempts
        ExecutorService pool = Executors.newFixedThreadPool(10);
        CountDownLatch ready = new CountDownLatch(10);
        CountDownLatch start = new CountDownLatch(1);

        List<Future<Boolean>> futures = new ArrayList<>();
        for (int i = 0; i < 10; i++) {
            UUID invId = invitationIds.get(i);
            UUID userId = candidateUsers.get(i);
            futures.add(pool.submit(() -> {
                ready.countDown();
                start.await();
                try {
                    admissionService.acceptInvitation(invId, userId);
                    return true;
                } catch (BusinessException ex) {
                    return false;
                }
            }));
        }

        assertTrue(ready.await(10, TimeUnit.SECONDS));
        start.countDown();

        int successCount = 0;
        for (Future<Boolean> future : futures) {
            if (future.get(20, TimeUnit.SECONDS)) {
                successCount++;
            }
        }
        pool.shutdownNow();

        assertEquals(2, successCount, "Exactly 2 concurrent admissions should succeed when 98 slots are taken");
        assertEquals(100, groupMembershipRepository.countByGroupIdAndStatus(groupId, GroupMembershipStatus.ACTIVE));
    }

    @Test
    void case2_inviteLinkMaxUsesFive_fifteenConcurrentJoins_exactlyFiveSucceed() throws Exception {
        UUID ownerId = createUser();
        UUID groupId = createGroup(ownerId);

        // Create invite link with maxUses = 5
        String code = "concurrent-link-5";
        groupInviteLinkRepository.save(new GroupInviteLinkEntity(
                UUID.randomUUID(), groupId, code, ownerId, 5, 0, null, false, NOW
        ));

        // 15 candidate users
        List<UUID> candidateUsers = new ArrayList<>();
        for (int i = 0; i < 15; i++) {
            candidateUsers.add(createUser());
        }

        ExecutorService pool = Executors.newFixedThreadPool(15);
        CountDownLatch ready = new CountDownLatch(15);
        CountDownLatch start = new CountDownLatch(1);

        List<Future<Boolean>> futures = new ArrayList<>();
        for (UUID candidate : candidateUsers) {
            futures.add(pool.submit(() -> {
                ready.countDown();
                start.await();
                try {
                    admissionService.joinViaInviteCode(code, candidate);
                    return true;
                } catch (BusinessException ex) {
                    return false;
                }
            }));
        }

        assertTrue(ready.await(10, TimeUnit.SECONDS));
        start.countDown();

        int successCount = 0;
        for (Future<Boolean> future : futures) {
            if (future.get(20, TimeUnit.SECONDS)) {
                successCount++;
            }
        }
        pool.shutdownNow();

        assertEquals(5, successCount, "Exactly 5 joins should succeed when maxUses = 5");
        GroupInviteLinkEntity updatedLink = groupInviteLinkRepository.findByCode(code).orElseThrow();
        assertEquals(5, updatedLink.getUsesCount());
    }

    private UUID createUser() {
        UUID id = UUID.randomUUID();
        userRepository.save(new UserEntity(
                id, "u_" + id.toString().substring(0, 8), "user_" + id.toString().substring(0, 8) + "@wedo.test",
                "Password123!", "User " + id.toString().substring(0, 4), null, null, null, null,
                UserStatus.ACTIVE, true, NOW, null, NOW, NOW
        ));
        return id;
    }

    private UUID createGroup(UUID ownerId) {
        UUID id = UUID.randomUUID();
        groupRepository.save(new GroupEntity(
                id, "Concurrency Group", "Desc", null, GroupStatus.ACTIVE, ownerId, NOW, NOW
        ));
        groupSettingsRepository.save(GroupSettingsEntity.createDefault(id, NOW));
        addMembership(id, ownerId, GroupRole.OWNER, GroupMembershipStatus.ACTIVE);
        return id;
    }

    private void addMembership(UUID groupId, UUID userId, GroupRole role, GroupMembershipStatus status) {
        groupMembershipRepository.save(new GroupMembershipEntity(
                UUID.randomUUID(), groupId, userId, role, status, NOW, null
        ));
    }
}
