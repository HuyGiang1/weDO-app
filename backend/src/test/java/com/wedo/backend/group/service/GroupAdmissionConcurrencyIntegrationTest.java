package com.wedo.backend.group.service;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.group.dto.CreateInvitationRequest;
import com.wedo.backend.group.dto.CreateInviteLinkRequest;
import com.wedo.backend.group.dto.GroupInvitationResponse;
import com.wedo.backend.group.dto.InviteLinkResponse;
import com.wedo.backend.group.dto.JoinRequestResponse;
import com.wedo.backend.group.entity.GroupEntity;
import com.wedo.backend.group.entity.GroupActivityAction;
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
    @Autowired private GroupActivityLogRepository groupActivityLogRepository;
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

        List<JoinOutcome> outcomes = concurrentlyJoin(code, candidateUsers);

        assertEquals(5, outcomes.stream().filter(JoinOutcome::succeeded).count(), "Exactly 5 joins should succeed when maxUses = 5");
        assertEquals(10, outcomes.stream().filter(outcome -> outcome.errorCode() == ErrorCode.INVITE_LINK_LIMIT_REACHED).count());
        assertTrue(outcomes.stream().allMatch(outcome -> outcome.succeeded() || outcome.errorCode() == ErrorCode.INVITE_LINK_LIMIT_REACHED),
                () -> "Unexpected worker outcome: " + outcomes);
        GroupInviteLinkEntity updatedLink = groupInviteLinkRepository.findByCode(code).orElseThrow();
        assertEquals(5, updatedLink.getUsesCount());
        assertEquals(5, candidateUsers.stream().filter(candidate -> groupMembershipRepository
                .findFirstByGroupIdAndUserIdAndStatus(groupId, candidate, GroupMembershipStatus.ACTIVE).isPresent()).count());
        assertEquals(5, groupActivityLogRepository.findByGroupId(groupId).stream()
                .filter(log -> log.getAction() == GroupActivityAction.GROUP_MEMBER_JOINED)
                .count(), "Only successful joins write membership activity");
    }

    @Test
    void inviteLinkMaxUsesOne_concurrentJoins_exactlyOneSucceeds() throws Exception {
        UUID ownerId = createUser();
        UUID groupId = createGroup(ownerId);
        String code = "concurrent-link-1";
        groupInviteLinkRepository.save(new GroupInviteLinkEntity(
                UUID.randomUUID(), groupId, code, ownerId, 1, 0, null, false, NOW));
        List<UUID> candidates = List.of(createUser(), createUser(), createUser(), createUser(), createUser());

        List<JoinOutcome> outcomes = concurrentlyJoin(code, candidates);

        assertEquals(1, outcomes.stream().filter(JoinOutcome::succeeded).count());
        assertEquals(4, outcomes.stream().filter(outcome -> outcome.errorCode() == ErrorCode.INVITE_LINK_LIMIT_REACHED).count());
        assertEquals(1, groupInviteLinkRepository.findByCode(code).orElseThrow().getUsesCount());
        assertEquals(1, candidates.stream().filter(candidate -> groupMembershipRepository
                .findFirstByGroupIdAndUserIdAndStatus(groupId, candidate, GroupMembershipStatus.ACTIVE).isPresent()).count());
    }

    @Test
    void unlimitedInviteLink_concurrentJoins_allSucceedBelowCapacity() throws Exception {
        UUID ownerId = createUser();
        UUID groupId = createGroup(ownerId);
        String code = "unlimited-link";
        groupInviteLinkRepository.save(new GroupInviteLinkEntity(
                UUID.randomUUID(), groupId, code, ownerId, null, 0, null, false, NOW));
        List<UUID> candidates = new ArrayList<>();
        for (int i = 0; i < 15; i++) candidates.add(createUser());

        List<JoinOutcome> outcomes = concurrentlyJoin(code, candidates);

        assertEquals(15, outcomes.stream().filter(JoinOutcome::succeeded).count(), outcomes::toString);
        assertEquals(0, outcomes.stream().filter(outcome -> !outcome.succeeded()).count());
        assertEquals(15, groupInviteLinkRepository.findByCode(code).orElseThrow().getUsesCount());
        assertEquals(16, groupMembershipRepository.countByGroupIdAndStatus(groupId, GroupMembershipStatus.ACTIVE));
    }

    @Test
    void revokedAndExpiredLinks_doNotConsumeUsageOrCreateMembership() {
        UUID ownerId = createUser();
        UUID groupId = createGroup(ownerId);
        UUID revokedUser = createUser();
        UUID expiredUser = createUser();
        GroupInviteLinkEntity revoked = groupInviteLinkRepository.save(new GroupInviteLinkEntity(
                UUID.randomUUID(), groupId, "revoked-link", ownerId, 2, 0, null, true, NOW));
        GroupInviteLinkEntity expired = groupInviteLinkRepository.save(new GroupInviteLinkEntity(
                UUID.randomUUID(), groupId, "expired-link", ownerId, 2, 0, NOW.minusSeconds(1), false, NOW));

        assertEquals(ErrorCode.INVITE_LINK_REVOKED, joinError("revoked-link", revokedUser));
        assertEquals(ErrorCode.INVITE_LINK_EXPIRED, joinError("expired-link", expiredUser));
        assertEquals(0, groupInviteLinkRepository.findById(revoked.getId()).orElseThrow().getUsesCount());
        assertEquals(0, groupInviteLinkRepository.findById(expired.getId()).orElseThrow().getUsesCount());
        assertTrue(groupMembershipRepository.findFirstByGroupIdAndUserIdAndStatus(groupId, revokedUser, GroupMembershipStatus.ACTIVE).isEmpty());
        assertTrue(groupMembershipRepository.findFirstByGroupIdAndUserIdAndStatus(groupId, expiredUser, GroupMembershipStatus.ACTIVE).isEmpty());
    }

    @Test
    void rejectedAdmission_doesNotConsumeUsage() {
        UUID ownerId = createUser();
        UUID groupId = createGroup(ownerId);
        String code = "failure-does-not-consume";
        GroupInviteLinkEntity link = groupInviteLinkRepository.save(new GroupInviteLinkEntity(
                UUID.randomUUID(), groupId, code, ownerId, 5, 0, null, false, NOW));
        UUID alreadyMember = createUser();
        addMembership(groupId, alreadyMember, GroupRole.MEMBER, GroupMembershipStatus.ACTIVE);

        assertEquals(ErrorCode.ALREADY_GROUP_MEMBER, joinError(code, alreadyMember));
        assertEquals(0, groupInviteLinkRepository.findById(link.getId()).orElseThrow().getUsesCount());
    }

    @Test
    void approvalRequiredInvite_createsOnePendingRequestWithoutConsumingUsage() {
        UUID ownerId = createUser();
        UUID groupId = createGroup(ownerId);
        UUID applicant = createUser();
        groupSettingsRepository.save(new GroupSettingsEntity(groupId, GroupJoinPolicy.APPROVAL_REQUIRED,
                false, true, false, com.wedo.backend.group.entity.ChatHistoryPolicy.FULL_HISTORY, NOW, NOW));
        GroupInviteLinkEntity link = groupInviteLinkRepository.save(new GroupInviteLinkEntity(
                UUID.randomUUID(), groupId, "approval-link", ownerId, 5, 0, null, false, NOW));

        Object result = admissionService.joinViaInviteCode("approval-link", applicant);

        assertTrue(result instanceof JoinRequestResponse);
        assertEquals(0, link.getUsesCount());
        assertTrue(groupMembershipRepository.findFirstByGroupIdAndUserIdAndStatus(groupId, applicant, GroupMembershipStatus.ACTIVE).isEmpty());
        assertEquals(ErrorCode.JOIN_REQUEST_ALREADY_PENDING, joinError("approval-link", applicant));
        assertEquals(0, groupInviteLinkRepository.findById(link.getId()).orElseThrow().getUsesCount());
    }

    @Test
    void concurrentRevokeAndJoin_hasNoDeadlockAndLeavesBoundedState() throws Exception {
        UUID ownerId = createUser();
        UUID groupId = createGroup(ownerId);
        UUID candidate = createUser();
        String code = "revoke-join-race";
        GroupInviteLinkEntity link = groupInviteLinkRepository.save(new GroupInviteLinkEntity(
                UUID.randomUUID(), groupId, code, ownerId, 1, 0, null, false, NOW));

        ExecutorService pool = Executors.newFixedThreadPool(2);
        CountDownLatch ready = new CountDownLatch(2);
        CountDownLatch start = new CountDownLatch(1);
        try {
            Future<JoinOutcome> join = pool.submit(() -> {
                ready.countDown();
                start.await();
                try {
                    admissionService.joinViaInviteCode(code, candidate);
                    return new JoinOutcome(candidate, null, null);
                } catch (BusinessException exception) {
                    return new JoinOutcome(candidate, exception.errorCode(), null);
                } catch (Throwable throwable) {
                    return new JoinOutcome(candidate, null, throwable);
                }
            });
            Future<Throwable> revoke = pool.submit(() -> {
                ready.countDown();
                start.await();
                try {
                    admissionService.revokeInviteLink(link.getId(), ownerId);
                    return null;
                } catch (Throwable throwable) {
                    return throwable;
                }
            });

            assertTrue(ready.await(10, TimeUnit.SECONDS));
            start.countDown();
            JoinOutcome joinOutcome = join.get(30, TimeUnit.SECONDS);
            assertNull(joinOutcome.unexpected(), () -> "Unexpected join failure: " + joinOutcome);
            assertNull(revoke.get(30, TimeUnit.SECONDS), "Revoke must not deadlock or fail");

            GroupInviteLinkEntity finalLink = groupInviteLinkRepository.findById(link.getId()).orElseThrow();
            assertTrue(finalLink.isRevoked());
            assertTrue(finalLink.getUsesCount() >= 0 && finalLink.getUsesCount() <= 1);
            assertTrue(groupMembershipRepository.findFirstByGroupIdAndUserIdAndStatus(groupId, candidate, GroupMembershipStatus.ACTIVE).isEmpty()
                    || finalLink.getUsesCount() == 1);
            assertTrue(joinOutcome.succeeded() || joinOutcome.errorCode() == ErrorCode.INVITE_LINK_REVOKED,
                    () -> "Unexpected join outcome: " + joinOutcome);
        } finally {
            pool.shutdownNow();
            assertTrue(pool.awaitTermination(10, TimeUnit.SECONDS));
        }
    }

    private UUID createUser() {
        UUID id = UUID.randomUUID();
        userRepository.save(new UserEntity(
                id, "user_" + id.toString().substring(0, 8) + "@wedo.test", "u_" + id.toString().substring(0, 8),
                "User " + id.toString().substring(0, 4), UserStatus.ACTIVE, NOW, NOW
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

    private List<JoinOutcome> concurrentlyJoin(String code, List<UUID> candidates) throws Exception {
        ExecutorService pool = Executors.newFixedThreadPool(candidates.size());
        CountDownLatch ready = new CountDownLatch(candidates.size());
        CountDownLatch start = new CountDownLatch(1);
        try {
            List<Future<JoinOutcome>> futures = new ArrayList<>();
            for (UUID candidate : candidates) {
                futures.add(pool.submit(() -> {
                    ready.countDown();
                    start.await();
                    try {
                        admissionService.joinViaInviteCode(code, candidate);
                        return new JoinOutcome(candidate, null, null);
                    } catch (BusinessException exception) {
                        return new JoinOutcome(candidate, exception.errorCode(), null);
                    } catch (Throwable throwable) {
                        return new JoinOutcome(candidate, null, throwable);
                    }
                }));
            }
            assertTrue(ready.await(10, TimeUnit.SECONDS), "Workers did not reach the barrier");
            start.countDown();
            List<JoinOutcome> outcomes = new ArrayList<>();
            for (Future<JoinOutcome> future : futures) outcomes.add(future.get(30, TimeUnit.SECONDS));
            assertTrue(outcomes.stream().noneMatch(outcome -> outcome.unexpected() != null), () -> "Unexpected worker failure: " + outcomes);
            return outcomes;
        } finally {
            pool.shutdownNow();
            assertTrue(pool.awaitTermination(10, TimeUnit.SECONDS), "Worker pool did not terminate");
        }
    }

    private ErrorCode joinError(String code, UUID userId) {
        BusinessException exception = assertThrows(BusinessException.class, () -> admissionService.joinViaInviteCode(code, userId));
        return exception.errorCode();
    }

    private record JoinOutcome(UUID userId, ErrorCode errorCode, Throwable unexpected) {
        boolean succeeded() { return errorCode == null && unexpected == null; }
    }
}
