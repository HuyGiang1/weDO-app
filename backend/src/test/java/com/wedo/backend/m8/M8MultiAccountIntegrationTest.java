package com.wedo.backend.m8;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.wedo.backend.activity.entity.ActivityEntity;
import com.wedo.backend.activity.entity.ActivityParticipantEntity;
import com.wedo.backend.activity.entity.ActivityRsvpStatus;
import com.wedo.backend.activity.entity.ActivityStatus;
import com.wedo.backend.activity.dto.UpdateActivityRequest;
import com.wedo.backend.activity.repository.ActivityParticipantRepository;
import com.wedo.backend.activity.repository.ActivityRepository;
import com.wedo.backend.activity.service.ActivityLifecycleService;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.discussion.dto.CommentResponse;
import com.wedo.backend.discussion.dto.CreateCommentRequest;
import com.wedo.backend.discussion.dto.UpdateCommentRequest;
import com.wedo.backend.discussion.service.DiscussionService;
import com.wedo.backend.group.entity.GroupEntity;
import com.wedo.backend.group.entity.GroupMembershipEntity;
import com.wedo.backend.group.entity.GroupMembershipStatus;
import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.group.repository.GroupMembershipRepository;
import com.wedo.backend.group.repository.GroupRepository;
import com.wedo.backend.group.service.GroupBanService;
import com.wedo.backend.poll.dto.CreatePollOptionRequest;
import com.wedo.backend.poll.dto.CreatePollRequest;
import com.wedo.backend.poll.dto.PollResponse;
import com.wedo.backend.poll.dto.VotePollRequest;
import com.wedo.backend.poll.entity.PollType;
import com.wedo.backend.poll.entity.ResultVisibility;
import com.wedo.backend.poll.entity.VoteVisibility;
import com.wedo.backend.poll.service.PollService;
import com.wedo.backend.task.dto.CreateTaskRequest;
import com.wedo.backend.task.dto.TaskResponse;
import com.wedo.backend.task.dto.UpdateTaskRequest;
import com.wedo.backend.task.dto.UpdateTaskStatusRequest;
import com.wedo.backend.task.entity.TaskStatus;
import com.wedo.backend.task.repository.TaskRepository;
import com.wedo.backend.task.service.TaskService;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserRepository;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * Deterministic real-PostgreSQL M8 persona coverage.
 * Run with: .\mvnw.cmd -Dtest=M8MultiAccountIntegrationTest test
 */
class M8MultiAccountIntegrationTest extends AbstractPostgresIntegrationTest {
    @org.springframework.test.context.bean.override.mockito.MockitoBean com.google.firebase.FirebaseApp firebaseAdminApp;
    @org.springframework.test.context.bean.override.mockito.MockitoBean com.google.firebase.messaging.FirebaseMessaging firebaseMessaging;
    private static final Instant NOW = Instant.parse("2026-09-26T00:00:00Z");

    @Autowired private UserRepository users;
    @Autowired private GroupRepository groups;
    @Autowired private GroupMembershipRepository memberships;
    @Autowired private ActivityRepository activities;
    @Autowired private ActivityParticipantRepository participants;
    @Autowired private ActivityLifecycleService activityLifecycle;
    @Autowired private TaskRepository tasks;
    @Autowired private PollService polls;
    @Autowired private com.wedo.backend.chat.service.ChatService chat;
    @Autowired private TaskService taskService;
    @Autowired private DiscussionService discussions;
    @Autowired private GroupBanService bans;
    @Autowired private JdbcTemplate jdbc;
    @Autowired private com.wedo.backend.activity.service.ActivityRsvpService rsvps;
    @Autowired private com.wedo.backend.activity.service.ActivityParticipantService participantService;
    @Autowired private com.wedo.backend.social.service.FriendRequestService friendRequests;
    @Autowired private com.wedo.backend.social.service.FriendshipService friendships;
    @Autowired private com.wedo.backend.social.service.RelationshipService relationships;
    @Autowired private com.wedo.backend.realtime.DomainRealtimeCoordinator realtime;
    @Autowired private org.springframework.transaction.PlatformTransactionManager transactionManager;
    @Autowired private com.wedo.backend.realtime.RealtimeScopeAccess realtimeAccess;
    @Autowired private com.wedo.backend.notification.service.NotificationService notificationService;

    @Test
    void personalReadModelFanoutFollowsCommittedRsvpWithoutGroupListRefresh() throws Exception {
        Fixture f = fixture();
        try (var peer = new com.wedo.backend.realtime.RealtimeProbe(realtime, f.owner(), "user:self")) {
            rsvps.changeRsvp(f.activityId(), f.memberC(), new com.wedo.backend.activity.dto.ChangeRsvpRequest(ActivityRsvpStatus.GOING));
            awaitDelivery();
            peer.await("HOME_CHANGED");
            peer.await("CALENDAR_CHANGED");
            assertTrue(peer.frames.stream().noneMatch(frame -> frame.contains("GROUP_LIST_CHANGED")));
        }
    }

    @Test
    void pollTaskDiscussionAndMembershipEventsUseRealAuthorizedScopes() throws Exception {
        Fixture f = fixture();
        assertFalse(realtimeAccess.allowed("activity:" + f.activityId(), f.outsider()));
        assertFalse(realtimeAccess.canViewJoinRequests(f.groupId(), f.memberC()));
        assertTrue(realtimeAccess.canViewJoinRequests(f.groupId(), f.owner()));
        try (var peer = new com.wedo.backend.realtime.RealtimeProbe(realtime, f.memberC(), "activity:" + f.activityId())) {
            var poll = polls.create(f.activityId(), f.owner(), pollRequest(VoteVisibility.ANONYMOUS));
            peer.await("POLL_CREATED");
            polls.vote(poll.id(), f.memberD(), new VotePollRequest(List.of(poll.options().getFirst().id())));
            String vote = peer.await("POLL_VOTE_CHANGED");
            assertFalse(vote.contains(f.memberD().toString()), "Anonymous vote identity must not enter the event");
            polls.close(poll.id(), f.owner());
            peer.await("POLL_CLOSED");
            rsvps.changeRsvp(f.activityId(), f.memberD(), new com.wedo.backend.activity.dto.ChangeRsvpRequest(ActivityRsvpStatus.GOING));
            var task = taskService.create(f.activityId(), f.owner(), new CreateTaskRequest("Realtime task", null, List.of(), null));
            peer.await("TASK_CREATED");
            taskService.claim(task.id(), f.memberD());
            peer.await("TASK_ASSIGNMENT_CHANGED");
            taskService.changeStatus(task.id(), f.memberD(), new UpdateTaskStatusRequest(TaskStatus.DONE));
            peer.await("TASK_STATUS_CHANGED");
            var comment = discussions.create(f.activityId(), f.owner(), new CreateCommentRequest("Private discussion body"));
            peer.await("DISCUSSION_COMMENT_CREATED");
            discussions.reply(comment.id(), f.memberD(), new CreateCommentRequest("Private reply body"));
            peer.await("DISCUSSION_REPLY_CREATED");
            assertTrue(peer.frames.stream().noneMatch(frame -> frame.contains("Private discussion body") || frame.contains("Private reply body")));
            peer.frames.clear();
            bans.banMember(f.groupId(), f.memberC(), f.owner(), "Realtime isolated fixture");
            org.awaitility.Awaitility.await().atMost(java.time.Duration.ofSeconds(10)).until(() ->
                    peer.frames.stream().anyMatch(frame -> frame.contains("SCOPE_REVOKED")));
            awaitDelivery();
            assertFalse(realtimeAccess.allowed("activity:" + f.activityId(), f.memberC()));
            assertTrue(peer.frames.stream().noneMatch(frame -> frame.contains("DOMAIN_CHANGED")));
        }
    }

    @Test
    void friendshipAndInboxReadChangesSynchronizeOnlyTheRecipientUserScope() throws Exception {
        Fixture f = fixture();
        try (var peer = new com.wedo.backend.realtime.RealtimeProbe(realtime, f.owner(), "user:self")) {
            var request = friendRequests.sendFriendRequest(f.owner(), f.memberC());
            peer.await("FRIEND_REQUESTED");
            friendRequests.acceptFriendRequest(f.memberC(), request.id());
            peer.await("FRIEND_ACCEPTED");
            peer.await("NOTIFICATION_CREATED");
            UUID notificationId = jdbc.queryForObject("SELECT id FROM notifications WHERE user_id=? AND data->>'eventType'='FRIEND_REQUEST_ACCEPTED'", UUID.class, f.owner());
            notificationService.markRead(notificationId, f.owner());
            peer.await("NOTIFICATION_READ");
            friendships.unfriend(f.owner(), f.memberC());
            peer.await("FRIEND_REMOVED");
            assertFalse(realtimeAccess.allowed("user:" + f.owner(), f.memberC()));
        }
    }

    @Test
    void realtimeRsvpUsesCommittedPostgresStateAndNeverLeaksRolledBackChanges() throws Exception {
        Fixture f = fixture();
        var socket = org.mockito.Mockito.mock(org.springframework.web.socket.WebSocketSession.class);
        org.mockito.Mockito.when(socket.getId()).thenReturn("r1-" + UUID.randomUUID());
        org.mockito.Mockito.when(socket.isOpen()).thenReturn(true);
        var frames = new java.util.concurrent.CopyOnWriteArrayList<String>();
        org.mockito.Mockito.doAnswer(call -> {
            frames.add(((org.springframework.web.socket.TextMessage) call.getArgument(0)).getPayload());
            return null;
        }).when(socket).sendMessage(org.mockito.ArgumentMatchers.any());
        realtime.register(socket, f.owner());
        try (var personal = new com.wedo.backend.realtime.RealtimeProbe(realtime, f.owner(), "user:self")) {
            realtime.command(socket, "{\"type\":\"SUBSCRIBE_SCOPE\",\"scope\":\"activity:" + f.activityId() + "\"}");
            assertTrue(frames.removeIf(frame -> frame.contains("SCOPE_SUBSCRIBED")));
            var tx = new org.springframework.transaction.support.TransactionTemplate(transactionManager);
            tx.executeWithoutResult(status -> {
                rsvps.changeRsvp(f.activityId(), f.memberC(),
                        new com.wedo.backend.activity.dto.ChangeRsvpRequest(ActivityRsvpStatus.GOING));
                assertTrue(frames.isEmpty(), "No socket publication inside uncommitted mutation");
            });
            awaitDelivery();
            assertEquals(1, frames.stream().filter(frame -> frame.contains("ACTIVITY_RSVP_CHANGED")).count());
            assertEquals(1L, participantService.list(f.activityId(), f.owner()).stream()
                    .filter(p -> p.userId().equals(f.memberC()) && p.rsvpStatus() == ActivityRsvpStatus.GOING).count());
            frames.clear();
            personal.frames.clear();
            tx.executeWithoutResult(status -> {
                rsvps.changeRsvp(f.activityId(), f.memberC(),
                        new com.wedo.backend.activity.dto.ChangeRsvpRequest(ActivityRsvpStatus.NOT_GOING));
                status.setRollbackOnly();
            });
            awaitDelivery();
            assertTrue(frames.isEmpty(), "Rolled-back RSVP must not send a domain frame");
            assertTrue(personal.frames.isEmpty(), "Rolled-back RSVP must not invalidate read models");
            assertEquals(ActivityRsvpStatus.GOING, participants.findByActivityIdAndUserId(f.activityId(), f.memberC()).orElseThrow().getRsvpStatus());
        } finally { realtime.unregister(socket); }
    }

    @Test
    void rsvpPromotionUsesOneCommittedHintAndRevokesLostMembership() throws Exception {
        Fixture f = fixture();
        jdbc.update("UPDATE activities SET capacity=1 WHERE id=?", f.activityId());
        String scope = "activity:" + f.activityId();
        assertFalse(realtimeAccess.allowed(scope, f.outsider()));
        // Real production authorization must deny a socket command, not only a helper lookup.
        var denied = org.mockito.Mockito.mock(org.springframework.web.socket.WebSocketSession.class);
        org.mockito.Mockito.when(denied.getId()).thenReturn("outsider-" + UUID.randomUUID());
        org.mockito.Mockito.when(denied.isOpen()).thenReturn(true);
        realtime.register(denied, f.outsider());
        try {
            realtime.command(denied, "{\"type\":\"SUBSCRIBE_SCOPE\",\"scope\":\"" + scope + "\"}");
            var frame = org.mockito.ArgumentCaptor.forClass(org.springframework.web.socket.TextMessage.class);
            org.mockito.Mockito.verify(denied).sendMessage(frame.capture());
            assertTrue(frame.getValue().getPayload().contains("SCOPE_DENIED"));
        } finally { realtime.unregister(denied); }
        rsvps.changeRsvp(f.activityId(), f.memberC(), new com.wedo.backend.activity.dto.ChangeRsvpRequest(ActivityRsvpStatus.GOING));
        rsvps.changeRsvp(f.activityId(), f.memberD(), new com.wedo.backend.activity.dto.ChangeRsvpRequest(ActivityRsvpStatus.GOING));
        awaitDelivery();
        assertEquals(ActivityRsvpStatus.WAITLIST, participants.findByActivityIdAndUserId(f.activityId(), f.memberD()).orElseThrow().getRsvpStatus());
        try (var peer = new com.wedo.backend.realtime.RealtimeProbe(realtime, f.memberD(), scope)) {
            rsvps.changeRsvp(f.activityId(), f.memberC(), new com.wedo.backend.activity.dto.ChangeRsvpRequest(ActivityRsvpStatus.NOT_GOING));
            String event = peer.await("ACTIVITY_RSVP_CHANGED");
            awaitDelivery();
            assertEquals(1, peer.frames.stream().filter(raw -> raw.contains("DOMAIN_CHANGED")).count());
            assertTrue(event.contains(f.activityId().toString()));
            assertFalse(event.contains("ACTIVITY_PARTICIPANTS_CHANGED"));
            assertFalse(event.contains("\"version\""));
            var current = participantService.list(f.activityId(), f.memberD());
            assertEquals(1, current.stream().filter(p -> p.rsvpStatus() == ActivityRsvpStatus.GOING).count());
            assertEquals(0, current.stream().filter(p -> p.rsvpStatus() == ActivityRsvpStatus.WAITLIST).count());
            assertEquals(ActivityRsvpStatus.GOING, participants.findByActivityIdAndUserId(f.activityId(), f.memberD()).orElseThrow().getRsvpStatus());
            peer.frames.clear();
            bans.banMember(f.groupId(), f.memberD(), f.owner(), "RSVP realtime isolated fixture");
            org.awaitility.Awaitility.await().atMost(java.time.Duration.ofSeconds(10)).until(() ->
                    peer.frames.stream().anyMatch(raw -> raw.contains("SCOPE_REVOKED")));
            awaitDelivery();
            peer.frames.clear();
            rsvps.changeRsvp(f.activityId(), f.memberC(), new com.wedo.backend.activity.dto.ChangeRsvpRequest(ActivityRsvpStatus.GOING));
            awaitDelivery();
            assertTrue(peer.frames.stream().noneMatch(raw -> raw.contains("DOMAIN_CHANGED")));
        }
    }

    @Test
    void friendshipLifecycleUsesOnlyPendingRequestsAndNotifiesOnlySenderOnce() {
        Fixture f = fixture();
        var none = com.wedo.backend.social.dto.RelationshipState.NONE;
        assertEquals(none, relationships.getRelationshipState(f.owner(), f.memberC()));
        var request = friendRequests.sendFriendRequest(f.owner(), f.memberC());
        assertEquals(com.wedo.backend.social.dto.RelationshipState.PENDING_SENT, relationships.getRelationshipState(f.owner(), f.memberC()));
        assertEquals(com.wedo.backend.social.dto.RelationshipState.PENDING_RECEIVED, relationships.getRelationshipState(f.memberC(), f.owner()));
        friendRequests.cancelFriendRequest(f.owner(), request.id());
        assertEquals(none, relationships.getRelationshipState(f.owner(), f.memberC()));
        var second = friendRequests.sendFriendRequest(f.owner(), f.memberC());
        friendRequests.acceptFriendRequest(f.memberC(), second.id());
        assertEquals(com.wedo.backend.social.dto.RelationshipState.FRIENDS, relationships.getRelationshipState(f.owner(), f.memberC()));
        org.awaitility.Awaitility.await().atMost(java.time.Duration.ofSeconds(10)).untilAsserted(() ->
                assertEquals(1, jdbc.queryForObject("SELECT count(*) FROM notifications WHERE user_id=? AND data->>'eventKey'=?", Integer.class, f.owner(), "FRIEND_REQUEST_ACCEPTED:" + second.id() + ":" + f.owner())));
        assertEquals(0, jdbc.queryForObject("SELECT count(*) FROM notifications WHERE user_id=? AND data->>'eventType'='FRIEND_REQUEST_ACCEPTED'", Integer.class, f.memberC()));
        assertCode(ErrorCode.CONFLICT, () -> friendRequests.acceptFriendRequest(f.memberC(), second.id()));
        friendships.unfriend(f.owner(), f.memberC());
        assertEquals(none, relationships.getRelationshipState(f.owner(), f.memberC()));
        assertEquals(none, relationships.getRelationshipState(f.memberC(), f.owner()));
        friendRequests.sendFriendRequest(f.owner(), f.memberC());
        assertEquals(com.wedo.backend.social.dto.RelationshipState.PENDING_SENT, relationships.getRelationshipState(f.owner(), f.memberC()));
    }

    @Test
    void pollPersonasCoverVotingClosureAnonymityAndOutsiderProtection() {
        Fixture fixture = fixture();
        PollResponse publicPoll = polls.create(fixture.activityId, fixture.owner(), pollRequest(VoteVisibility.PUBLIC));
        assertNotification(fixture.admin(), "POLL_CREATED", "POLL", "POLL", publicPoll.id(), fixture.activityId);
        assertNotification(fixture.memberC(), "POLL_CREATED", "POLL", "POLL", publicPoll.id(), fixture.activityId);
        assertNotification(fixture.memberD(), "POLL_CREATED", "POLL", "POLL", publicPoll.id(), fixture.activityId);
        assertNotificationCount(fixture.owner(), "POLL_CREATED", publicPoll.id(), 0);
        UUID optionA = publicPoll.options().get(0).id();
        UUID optionB = publicPoll.options().get(1).id();

        polls.vote(publicPoll.id(), fixture.memberC(), new VotePollRequest(List.of(optionA)));
        polls.vote(publicPoll.id(), fixture.memberD(), new VotePollRequest(List.of(optionB)));
        PollResponse changedVote = polls.vote(publicPoll.id(), fixture.memberC(), new VotePollRequest(List.of(optionB)));
        assertEquals(List.of(optionB), changedVote.callerOptionIds());
        assertFalse(changedVote.permissions().canAddOption());
        assertCode(ErrorCode.INSUFFICIENT_GROUP_PERMISSION,
                () -> polls.addOption(publicPoll.id(), fixture.memberC(), new CreatePollOptionRequest("Nope")));
        assertCode(ErrorCode.GROUP_NOT_FOUND,
                () -> polls.vote(publicPoll.id(), fixture.outsider(), new VotePollRequest(List.of(optionA))));

        polls.close(publicPoll.id(), fixture.admin());
        assertNotification(fixture.owner(), "POLL_CLOSED", "POLL", "POLL", publicPoll.id(), fixture.activityId);
        assertNotification(fixture.memberC(), "POLL_CLOSED", "POLL", "POLL", publicPoll.id(), fixture.activityId);
        assertNotification(fixture.memberD(), "POLL_CLOSED", "POLL", "POLL", publicPoll.id(), fixture.activityId);
        assertNotificationCount(fixture.admin(), "POLL_CLOSED", publicPoll.id(), 0);
        assertCode(ErrorCode.POLL_CLOSED,
                () -> polls.vote(publicPoll.id(), fixture.memberC(), new VotePollRequest(List.of(optionA))));

        PollResponse anonymousPoll = polls.create(fixture.activityId, fixture.owner(), pollRequest(VoteVisibility.ANONYMOUS));
        polls.vote(anonymousPoll.id(), fixture.memberC(), new VotePollRequest(List.of(anonymousPoll.options().get(0).id())));
        assertCode(ErrorCode.POLL_VOTERS_PRIVATE, () -> polls.voters(anonymousPoll.id(), fixture.owner()));
    }

    @Test
    void taskPersonasCoverAssignmentStatusClaimDeletionAndOutsiderProtection() {
        Fixture fixture = fixture();
        rsvps.changeRsvp(fixture.activityId, fixture.memberC(), new com.wedo.backend.activity.dto.ChangeRsvpRequest(ActivityRsvpStatus.GOING));
        rsvps.changeRsvp(fixture.activityId, fixture.memberD(), new com.wedo.backend.activity.dto.ChangeRsvpRequest(ActivityRsvpStatus.GOING));
        TaskResponse assigned = taskService.create(fixture.activityId, fixture.owner(),
                new CreateTaskRequest("Assigned", null, List.of(fixture.memberC()), null));
        assertNotification(fixture.memberC(), "TASK_ASSIGNED", "TASK", "TASK", assigned.id(), fixture.activityId);
        assertNotificationCount(fixture.owner(), "TASK_ASSIGNED", assigned.id(), 0);
        assertTrue(taskService.get(assigned.id(), fixture.owner()).permissions().canDelete());
        assertFalse(taskService.get(assigned.id(), fixture.memberC()).permissions().canDelete());
        assertTrue(taskService.get(assigned.id(), fixture.memberC()).permissions().canChangeStatus());
        taskService.changeStatus(assigned.id(), fixture.memberC(), new UpdateTaskStatusRequest(TaskStatus.IN_PROGRESS));
        assertNotification(fixture.owner(), "TASK_STATUS_CHANGED", "TASK", "TASK", assigned.id(), fixture.activityId);
        assertNotificationCount(fixture.memberC(), "TASK_STATUS_CHANGED", assigned.id(), 0);
        assertCode(ErrorCode.TASK_UPDATE_NOT_ALLOWED,
                () -> taskService.changeStatus(assigned.id(), fixture.memberD(), new UpdateTaskStatusRequest(TaskStatus.DONE)));
        TaskResponse adminUpdated = taskService.update(assigned.id(), fixture.admin(),
                new UpdateTaskRequest("Admin updated", null, null, List.of(fixture.memberC())));
        assertTrue(adminUpdated.permissions().canManageAssignees());
        assertFalse(adminUpdated.permissions().canChangeStatus());
        assertCode(ErrorCode.TASK_UPDATE_NOT_ALLOWED,
                () -> taskService.changeStatus(assigned.id(), fixture.admin(), new UpdateTaskStatusRequest(TaskStatus.DONE)));

        TaskResponse claimable = taskService.create(fixture.activityId, fixture.owner(),
                new CreateTaskRequest("Claimable", null, List.of(), null));
        assertTrue(taskService.get(claimable.id(), fixture.memberD()).permissions().canClaim());
        assertEquals(List.of(fixture.memberD()), taskService.claim(claimable.id(), fixture.memberD()).assigneeUserIds());
        assertCode(ErrorCode.GROUP_NOT_FOUND, () -> taskService.claim(claimable.id(), fixture.outsider()));

        taskService.delete(assigned.id(), fixture.owner());
        assertFalse(tasks.existsById(assigned.id()));
    }

    @Test
    void rsvpLeaveHidesHistoricalRowAndTaskEligibilityPreservesExistingAssignment() {
        Fixture f = fixture();
        assertCode(ErrorCode.TASK_ASSIGNEE_NOT_PARTICIPANT, () -> taskService.create(f.activityId, f.owner(),
                new CreateTaskRequest("Invalid", null, List.of(f.memberC()), null)));
        for (ActivityRsvpStatus status : List.of(ActivityRsvpStatus.MAYBE, ActivityRsvpStatus.NOT_GOING)) {
            rsvps.changeRsvp(f.activityId, f.memberC(), new com.wedo.backend.activity.dto.ChangeRsvpRequest(status));
            assertCode(ErrorCode.TASK_ASSIGNEE_NOT_PARTICIPANT, () -> taskService.create(f.activityId, f.owner(),
                    new CreateTaskRequest("Invalid", null, List.of(f.memberC()), null)));
        }
        rsvps.changeRsvp(f.activityId, f.memberC(), new com.wedo.backend.activity.dto.ChangeRsvpRequest(ActivityRsvpStatus.GOING));
        assertEquals(1, participantService.list(f.activityId, f.owner()).size());
        TaskResponse task = taskService.create(f.activityId, f.owner(), new CreateTaskRequest("Retained", null, List.of(f.memberC()), null));
        rsvps.changeRsvp(f.activityId, f.memberC(), new com.wedo.backend.activity.dto.ChangeRsvpRequest(ActivityRsvpStatus.NOT_GOING));
        assertTrue(participantService.list(f.activityId, f.owner()).isEmpty());
        assertEquals(0, participants.countByActivityIdAndRsvpStatus(f.activityId, ActivityRsvpStatus.GOING));
        assertEquals(ActivityRsvpStatus.NOT_GOING, participants.findByActivityIdAndUserId(f.activityId, f.memberC()).orElseThrow().getRsvpStatus());
        assertEquals(List.of(f.memberC()), taskService.update(task.id(), f.owner(), new UpdateTaskRequest("Retained title", null, null, List.of(f.memberC()))).assigneeUserIds());
        assertEquals(TaskStatus.DONE, taskService.changeStatus(task.id(), f.memberC(), new UpdateTaskStatusRequest(TaskStatus.DONE)).status());
        TaskResponse unassigned = taskService.create(f.activityId, f.owner(), new CreateTaskRequest("Unassigned", null, List.of(), null));
        assertFalse(taskService.get(unassigned.id(), f.memberC()).permissions().canClaim());
        assertCode(ErrorCode.TASK_ASSIGNEE_NOT_PARTICIPANT, () -> taskService.claim(unassigned.id(), f.memberC()));
        taskService.update(task.id(), f.owner(), new UpdateTaskRequest("Removed", null, null, List.of()));
        assertCode(ErrorCode.TASK_ASSIGNEE_NOT_PARTICIPANT, () -> taskService.update(task.id(), f.owner(), new UpdateTaskRequest("Cannot re-add", null, null, List.of(f.memberC()))));
        rsvps.changeRsvp(f.activityId, f.memberC(), new com.wedo.backend.activity.dto.ChangeRsvpRequest(ActivityRsvpStatus.GOING));
        assertEquals(1, participantService.list(f.activityId, f.owner()).size());
        assertTrue(taskService.get(unassigned.id(), f.memberC()).permissions().canClaim());
        assertEquals(List.of(f.memberC()), taskService.claim(unassigned.id(), f.memberC()).assigneeUserIds());
    }

    @Test
    void confirmedActivityScheduleChangesNotifyOnlyGoingAndMaybeParticipants() {
        Fixture fixture = fixture();
        participants.save(new ActivityParticipantEntity(UUID.randomUUID(), fixture.activityId(), fixture.memberC(),
                ActivityRsvpStatus.GOING, null, NOW, NOW, NOW));
        participants.save(new ActivityParticipantEntity(UUID.randomUUID(), fixture.activityId(), fixture.memberD(),
                ActivityRsvpStatus.MAYBE, null, NOW, NOW, NOW));
        participants.save(new ActivityParticipantEntity(UUID.randomUUID(), fixture.activityId(), fixture.admin(),
                ActivityRsvpStatus.NOT_GOING, null, NOW, NOW, NOW));

        activityLifecycle.update(fixture.activityId(), fixture.owner(), new UpdateActivityRequest(
                null, null, NOW.plusSeconds(86_400), null, "UTC", null, null));

        assertNotification(fixture.memberC(), "ACTIVITY_TIME_CHANGED", "ACTIVITY", "ACTIVITY",
                fixture.activityId(), fixture.activityId());
        assertNotification(fixture.memberD(), "ACTIVITY_TIME_CHANGED", "ACTIVITY", "ACTIVITY",
                fixture.activityId(), fixture.activityId());
        assertNotificationCount(fixture.admin(), "ACTIVITY_TIME_CHANGED", fixture.activityId(), 0);
        assertNotificationCount(fixture.owner(), "ACTIVITY_TIME_CHANGED", fixture.activityId(), 0);
    }

    @Test
    void discussionPersonasCoverIdentityModerationReadOnlyAndMembershipLoss() {
        Fixture fixture = fixture();
        CommentResponse root = discussions.create(fixture.activityId, fixture.memberC(), new CreateCommentRequest("Root"));
        CommentResponse reply = discussions.reply(root.id(), fixture.memberD(), new CreateCommentRequest("Reply"));
        assertEquals("MEMBER_C", root.author().displayName());
        assertEquals("MEMBER_D", reply.author().displayName());
        discussions.update(root.id(), fixture.memberC(), new UpdateCommentRequest("Edited"));
        assertCode(ErrorCode.COMMENT_UPDATE_NOT_ALLOWED,
                () -> discussions.update(root.id(), fixture.memberD(), new UpdateCommentRequest("Nope")));
        discussions.delete(root.id(), fixture.admin());
        assertCode(ErrorCode.GROUP_NOT_FOUND,
                () -> discussions.create(fixture.activityId, fixture.outsider(), new CreateCommentRequest("Nope")));

        fixture.activity.transitionTo(ActivityStatus.COMPLETED, NOW);
        activities.save(fixture.activity);
        assertTrue(discussions.list(fixture.activityId, fixture.memberC()).permissions().readOnly());
        assertCode(ErrorCode.ACTIVITY_CLOSED,
                () -> discussions.create(fixture.activityId, fixture.memberC(), new CreateCommentRequest("Closed")));
        fixture.activity.transitionTo(ActivityStatus.CANCELLED, NOW);
        activities.save(fixture.activity);
        assertTrue(discussions.list(fixture.activityId, fixture.memberD()).permissions().readOnly());

        Fixture archived = fixture();
        archived.group.archive(NOW);
        groups.save(archived.group);
        assertTrue(discussions.list(archived.activityId, archived.memberC()).permissions().readOnly());

        Fixture loss = fixture();
        loss.memberCMembership.endAsLeft(NOW);
        memberships.save(loss.memberCMembership);
        assertCode(ErrorCode.GROUP_NOT_FOUND,
                () -> discussions.create(loss.activityId, loss.memberC(), new CreateCommentRequest("Removed")));
        bans.banMember(loss.groupId, loss.memberD(), loss.owner(), "test");
        assertCode(ErrorCode.GROUP_NOT_FOUND,
                () -> discussions.create(loss.activityId, loss.memberD(), new CreateCommentRequest("Banned")));
    }

    @Test
    void p0RepeatedIdenticalVoteIsIdempotentInRealPostgres() {
        Fixture f = fixture();
        PollResponse p = polls.create(f.activityId(), f.owner(), pollRequest(VoteVisibility.PUBLIC));
        UUID a = p.options().getFirst().id();
        polls.vote(p.id(), f.memberC(), new VotePollRequest(List.of(a)));
        for (int i = 0; i < 3; i++) {
            PollResponse result = polls.vote(p.id(), f.memberC(), new VotePollRequest(List.of(a)));
            assertEquals(List.of(a), result.callerOptionIds());
            assertEquals(1, result.options().getFirst().voteCount());
        }
        assertEquals(1, jdbc.queryForObject("SELECT count(*) FROM poll_votes WHERE poll_id=?", Integer.class, p.id()));
    }

    @Test
    void p0OverlappingMultipleChoiceReplacementIsAtomic() {
        Fixture f = fixture();
        PollResponse p = polls.create(f.activityId(), f.owner(), new CreatePollRequest(
                "P0 multiple", PollType.MULTIPLE_CHOICE, List.of("A", "B", "C"), false, 2,
                VoteVisibility.ANONYMOUS, ResultVisibility.IMMEDIATE, null));
        UUID a = p.options().get(0).id(), b = p.options().get(1).id(), c = p.options().get(2).id();
        polls.vote(p.id(), f.memberC(), new VotePollRequest(List.of(a, b)));
        PollResponse replaced = polls.vote(p.id(), f.memberC(), new VotePollRequest(List.of(b, c)));
        assertEquals(java.util.Set.of(b, c), java.util.Set.copyOf(replaced.callerOptionIds()));
        assertEquals(List.of(0L, 1L, 1L), replaced.options().stream().map(o -> o.voteCount()).toList());
        assertCode(ErrorCode.MAX_POLL_SELECTIONS_EXCEEDED,
                () -> polls.vote(p.id(), f.memberC(), new VotePollRequest(List.of(a, b, c))));
        assertEquals(java.util.Set.of(b, c), java.util.Set.copyOf(polls.get(p.id(), f.memberC()).callerOptionIds()));
        assertCode(ErrorCode.POLL_VOTERS_PRIVATE, () -> polls.voters(p.id(), f.owner()));
        assertEquals(List.of(c), polls.vote(p.id(), f.memberC(), new VotePollRequest(List.of(c))).callerOptionIds());
    }

    @Test
    void p0ConcurrentRepeatsKeepOneBallotAndOneChoice() throws Exception {
        Fixture f = fixture();
        PollResponse p = polls.create(f.activityId(), f.owner(), pollRequest(VoteVisibility.PUBLIC));
        UUID a = p.options().getFirst().id();
        polls.vote(p.id(), f.memberC(), new VotePollRequest(List.of(a)));
        try (var pool = java.util.concurrent.Executors.newFixedThreadPool(4)) {
            var start = new java.util.concurrent.CountDownLatch(1);
            var futures = java.util.stream.IntStream.range(0, 4).mapToObj(i -> pool.submit(() -> {
                start.await();
                return polls.vote(p.id(), f.memberC(), new VotePollRequest(List.of(a)));
            })).toList();
            start.countDown();
            for (var future : futures) assertEquals(List.of(a), future.get(15, java.util.concurrent.TimeUnit.SECONDS).callerOptionIds());
        }
        assertEquals(1, polls.get(p.id(), f.owner()).options().getFirst().voteCount());
    }

    @Test
    void p0VoteReplacementRollbackKeepsOldBallotAndEmitsNothing() throws Exception {
        Fixture f = fixture();
        PollResponse p = polls.create(f.activityId(), f.owner(), pollRequest(VoteVisibility.PUBLIC));
        UUID a = p.options().get(0).id(), b = p.options().get(1).id();
        polls.vote(p.id(), f.memberC(), new VotePollRequest(List.of(a)));
        awaitDelivery();
        try (var peer = new com.wedo.backend.realtime.RealtimeProbe(realtime, f.memberD(), "activity:" + f.activityId())) {
            new org.springframework.transaction.support.TransactionTemplate(transactionManager).executeWithoutResult(tx -> {
                polls.vote(p.id(), f.memberC(), new VotePollRequest(List.of(b)));
                tx.setRollbackOnly();
            });
            awaitDelivery();
            assertTrue(peer.frames.stream().noneMatch(frame -> frame.contains("POLL_VOTE_CHANGED")));
        }
        assertEquals(List.of(a), polls.get(p.id(), f.memberC()).callerOptionIds());
        assertEquals(List.of(1L, 0L), polls.get(p.id(), f.owner()).options().stream().map(o -> o.voteCount()).toList());
    }

    @Test
    void p0OptionEditRespectsVotesAndManagerRights() {
        Fixture f = fixture();
        PollResponse p = polls.create(f.activityId(), f.owner(), pollRequest(VoteVisibility.PUBLIC));
        UUID a = p.options().get(0).id(), b = p.options().get(1).id();
        assertEquals("Renamed", polls.updateOption(p.id(), a, f.owner(), new com.wedo.backend.poll.dto.UpdatePollOptionRequest("Renamed")).options().getFirst().text());
        assertCode(ErrorCode.INSUFFICIENT_GROUP_PERMISSION, () -> polls.updateOption(p.id(), b, f.memberC(), new com.wedo.backend.poll.dto.UpdatePollOptionRequest("No")));
        polls.vote(p.id(), f.memberC(), new VotePollRequest(List.of(a)));
        assertCode(ErrorCode.POLL_OPTION_CHANGE_NOT_ALLOWED, () -> polls.updateOption(p.id(), a, f.owner(), new com.wedo.backend.poll.dto.UpdatePollOptionRequest("No")));
        polls.disableOption(p.id(), a, f.owner());
        assertCode(ErrorCode.POLL_OPTION_DISABLED, () -> polls.vote(p.id(), f.memberD(), new VotePollRequest(List.of(a))));
        assertEquals(List.of(a), polls.get(p.id(), f.memberC()).callerOptionIds());
    }

    @Test
    void chatPollIsCanonicalOrderedIdempotentAndViewerSafe() throws Exception {
        Fixture f = fixture();
        UUID conversation = chat.openGroup(f.groupId(), f.owner()).id();
        UUID key = UUID.randomUUID();
        var request = new com.wedo.backend.chat.dto.ChatRequests.CreatePoll(f.activityId(), key,
                new CreatePollRequest("Chat decision", PollType.MULTIPLE_CHOICE, List.of("A","B","C"), false, 2,
                    VoteVisibility.ANONYMOUS, ResultVisibility.AFTER_CLOSE, null));
        var message = chat.createPoll(conversation, f.owner(), request);
        assertEquals("POLL", message.type());
        assertEquals(key, message.id());
        assertFalse(message.permissions().canEdit());
        assertEquals(message.id(), chat.createPoll(conversation, f.owner(), request).id());
        assertEquals(1, chat.history(conversation, f.memberC(), null, 30).messages().size());
        assertEquals(message.pollId(), polls.list(f.activityId(), f.memberC()).getFirst().id());
        var p = polls.get(message.pollId(), f.memberC());
        var a = p.options().get(0).id(); var b = p.options().get(1).id(); var c = p.options().get(2).id();
        polls.vote(p.id(), f.memberC(), new VotePollRequest(List.of(a,b)));
        polls.vote(p.id(), f.memberC(), new VotePollRequest(List.of(b,c)));
        assertEquals(1, jdbc.queryForObject("SELECT count(*) FROM poll_votes WHERE poll_id=?", Integer.class, p.id()));
        assertFalse(polls.get(p.id(), f.memberD()).resultsVisible());
        assertCode(ErrorCode.POLL_VOTERS_PRIVATE, () -> polls.voters(p.id(), f.owner()));
        assertCode(ErrorCode.ACCESS_DENIED, () -> chat.edit(message.id(), f.owner(), new com.wedo.backend.chat.dto.ChatRequests.EditMessage("Not a Poll edit")));
        polls.close(p.id(), f.owner());
        assertEquals(List.of(0L,1L,1L), polls.get(p.id(), f.memberD()).options().stream().map(o -> o.voteCount()).toList());
        assertCode(ErrorCode.POLL_CLOSED, () -> polls.vote(p.id(), f.memberC(), new VotePollRequest(List.of(a))));
        bans.banMember(f.groupId(), f.memberC(), f.owner(), "isolated chat poll fixture");
        assertThrows(BusinessException.class, () -> chat.history(conversation, f.memberC(), null, 30));
        assertThrows(BusinessException.class, () -> polls.get(p.id(), f.memberC()));
        assertThrows(BusinessException.class, () -> polls.vote(p.id(), f.memberC(), new VotePollRequest(List.of(a))));
    }

    @Test
    void chatPollCreationRejectsOutsidersAndCrossGroupAndRollbackLeavesNoPhantom() throws Exception {
        Fixture f = fixture(); Fixture other = fixture();
        UUID conversation = chat.openGroup(f.groupId(), f.owner()).id();
        var bad = new com.wedo.backend.chat.dto.ChatRequests.CreatePoll(other.activityId(), UUID.randomUUID(), pollRequest(VoteVisibility.PUBLIC));
        assertThrows(BusinessException.class, () -> chat.createPoll(conversation, f.owner(), bad));
        var request = new com.wedo.backend.chat.dto.ChatRequests.CreatePoll(f.activityId(), UUID.randomUUID(), pollRequest(VoteVisibility.PUBLIC));
        assertThrows(BusinessException.class, () -> chat.createPoll(conversation, f.outsider(), request));
        try (var peer = new com.wedo.backend.realtime.RealtimeProbe(realtime, f.memberC(), "activity:"+f.activityId())) {
            new org.springframework.transaction.support.TransactionTemplate(transactionManager).executeWithoutResult(tx -> {
                chat.createPoll(conversation, f.owner(), request);
                assertTrue(peer.frames.isEmpty());
                tx.setRollbackOnly();
            });
            awaitDelivery();
            assertTrue(peer.frames.isEmpty());
        }
        assertTrue(polls.list(f.activityId(), f.owner()).isEmpty());
        assertTrue(chat.history(conversation, f.owner(), null, 30).messages().isEmpty());
        assertEquals(0L, jdbc.queryForObject("SELECT current_sequence FROM conversation_sequences WHERE conversation_id=?", Long.class, conversation));
        try (var peer = new com.wedo.backend.realtime.RealtimeProbe(realtime, f.memberC(), "activity:"+f.activityId())) {
            chat.createPoll(conversation, f.owner(), request);
            peer.await("POLL_CREATED");
        }
    }

    @Test
    void chatPollConcurrentRetryCreatesOnePollAndOneSequence() throws Exception {
        Fixture f = fixture(); UUID conversation = chat.openGroup(f.groupId(), f.owner()).id();
        var request = new com.wedo.backend.chat.dto.ChatRequests.CreatePoll(f.activityId(), UUID.randomUUID(), pollRequest(VoteVisibility.PUBLIC));
        try (var pool = java.util.concurrent.Executors.newFixedThreadPool(3)) {
            var results = java.util.stream.IntStream.range(0,3).mapToObj(i -> pool.submit(() -> chat.createPoll(conversation, f.owner(), request))).toList();
            UUID pollId = results.getFirst().get(15,java.util.concurrent.TimeUnit.SECONDS).pollId();
            for (var result : results) assertEquals(pollId,result.get(15,java.util.concurrent.TimeUnit.SECONDS).pollId());
        }
        assertEquals(1, polls.list(f.activityId(), f.owner()).size());
        assertEquals(1, chat.history(conversation, f.owner(), null, 30).messages().size());
    }

    @Test
    void deadlineReadPersistsClosureAndPublishesAfterCommitWithoutWidgetTimer() throws Exception {
        Fixture f = fixture(); var p = polls.create(f.activityId(), f.owner(), pollRequest(VoteVisibility.PUBLIC));
        awaitDelivery();
        jdbc.update("UPDATE polls SET deadline_at=now()-interval '1 minute' WHERE id=?", p.id());
        assertCode(ErrorCode.POLL_DEADLINE_PASSED, () -> polls.vote(p.id(), f.memberC(), new VotePollRequest(List.of(p.options().getFirst().id()))));
        try (var peer = new com.wedo.backend.realtime.RealtimeProbe(realtime, f.memberC(), "activity:"+f.activityId())) {
            assertEquals(com.wedo.backend.poll.entity.PollStatus.CLOSED, polls.get(p.id(), f.memberC()).status());
            peer.await("POLL_CLOSED");
            assertEquals("CLOSED", jdbc.queryForObject("SELECT status FROM polls WHERE id=?", String.class,p.id()));
        }
    }

    @Test
    void groupOnlyChatPollUsesGroupScopeHistoryAndExistingBallots() throws Exception {
        Fixture f=fixture(); UUID conversation=chat.openGroup(f.groupId(),f.owner()).id();
        var request=new com.wedo.backend.chat.dto.ChatRequests.CreatePoll(null,UUID.randomUUID(),pollRequest(VoteVisibility.ANONYMOUS));
        try(var peer=new com.wedo.backend.realtime.RealtimeProbe(realtime,f.memberC(),"group:"+f.groupId())) {
            var message=chat.createPoll(conversation,f.owner(),request);
            peer.await("POLL_CREATED");
            var p=polls.get(message.pollId(),f.memberC());
            assertEquals(f.groupId(),p.groupId()); assertEquals(null,p.activityId());
            assertTrue(polls.list(f.activityId(),f.owner()).isEmpty());
            assertEquals(message.pollId(),polls.listGroup(f.groupId(),f.memberC()).getFirst().id());
            UUID a=p.options().get(0).id(),b=p.options().get(1).id();
            polls.vote(p.id(),f.memberC(),new VotePollRequest(List.of(a)));
            String event=peer.await("POLL_VOTE_CHANGED");
            assertFalse(event.contains(f.memberC().toString()));
            assertEquals(List.of(b),polls.vote(p.id(),f.memberC(),new VotePollRequest(List.of(b))).callerOptionIds());
            assertEquals(message.id(),chat.createPoll(conversation,f.owner(),request).id());
            assertEquals(1,chat.history(conversation,f.memberD(),null,30).messages().size());
            polls.close(p.id(),f.owner()); peer.await("POLL_CLOSED");
            assertCode(ErrorCode.POLL_VOTERS_PRIVATE,()->polls.voters(p.id(),f.memberD()));
            assertThrows(BusinessException.class,()->polls.listGroup(f.groupId(),f.outsider()));
            bans.banMember(f.groupId(),f.memberC(),f.owner(),"isolated group-only poll");
            awaitDelivery();
            assertTrue(peer.frames.stream().anyMatch(frame->frame.contains("SCOPE_REVOKED")));
            assertThrows(BusinessException.class,()->polls.get(p.id(),f.memberC()));
        }
    }

    @Test
    void groupOnlyRollbackAndLegacyActivityInsertPreserveOwnership() throws Exception {
        Fixture f=fixture(); UUID conversation=chat.openGroup(f.groupId(),f.owner()).id();
        var request=new com.wedo.backend.chat.dto.ChatRequests.CreatePoll(null,UUID.randomUUID(),pollRequest(VoteVisibility.PUBLIC));
        new org.springframework.transaction.support.TransactionTemplate(transactionManager).executeWithoutResult(tx->{
            chat.createPoll(conversation,f.owner(),request);tx.setRollbackOnly();
        });
        assertTrue(polls.listGroup(f.groupId(),f.owner()).isEmpty());
        assertTrue(chat.history(conversation,f.owner(),null,30).messages().isEmpty());
        UUID legacy=UUID.randomUUID();
        jdbc.update("INSERT INTO polls(id,activity_id,created_by,question) VALUES (?,?,?,'Legacy insert')",legacy,f.activityId(),f.owner());
        assertEquals(f.groupId(),polls.get(legacy,f.owner()).groupId());
        Fixture other=fixture();
        assertThrows(org.springframework.dao.DataIntegrityViolationException.class,()->jdbc.update(
            "INSERT INTO polls(id,activity_id,group_id,created_by,question) VALUES (?,?,?,?,'Wrong group')",UUID.randomUUID(),f.activityId(),other.groupId(),f.owner()));
    }

    @Test
    void groupHistoryExpiryProjectionDoesNotWriteAnUnboundedBatch() throws Exception {
        Fixture f=fixture();
        var a=polls.createGroup(f.groupId(),f.owner(),pollRequest(VoteVisibility.PUBLIC));
        var b=polls.createGroup(f.groupId(),f.owner(),pollRequest(VoteVisibility.PUBLIC));
        awaitDelivery();
        jdbc.update("UPDATE polls SET deadline_at=now()-interval '1 minute' WHERE id IN (?,?)",a.id(),b.id());
        var history=polls.listGroup(f.groupId(),f.memberC());
        assertTrue(history.stream().allMatch(p->p.status()==com.wedo.backend.poll.entity.PollStatus.CLOSED&&!p.permissions().canVote()));
        assertEquals(2,jdbc.queryForObject("SELECT count(*) FROM polls WHERE group_id=? AND status='OPEN'",Integer.class,f.groupId()));
        polls.get(a.id(),f.memberC()); polls.get(a.id(),f.memberC());
        assertEquals(1,jdbc.queryForObject("SELECT count(*) FROM polls WHERE group_id=? AND status='CLOSED'",Integer.class,f.groupId()));
    }

    private Fixture fixture() {
        UUID suffix = UUID.randomUUID();
        UUID owner = UUID.randomUUID();
        UUID admin = UUID.randomUUID();
        UUID memberC = UUID.randomUUID();
        UUID memberD = UUID.randomUUID();
        UUID outsider = UUID.randomUUID();
        for (Persona persona : List.of(new Persona(owner, "OWNER_A"), new Persona(admin, "ADMIN_B"),
                new Persona(memberC, "MEMBER_C"), new Persona(memberD, "MEMBER_D"), new Persona(outsider, "OUTSIDER_E"))) {
            users.save(new UserEntity(persona.id(), persona.name().toLowerCase() + "+" + suffix + "@test.local",
                    persona.name().toLowerCase() + suffix.toString().substring(0, 8), persona.name(), UserStatus.ACTIVE, NOW, NOW));
        }
        UUID groupId = UUID.randomUUID();
        GroupEntity group = groups.save(new GroupEntity(groupId, "M8 personas", null, null, GroupStatus.ACTIVE, owner, NOW, NOW));
        memberships.save(new GroupMembershipEntity(UUID.randomUUID(), groupId, owner, GroupRole.OWNER, GroupMembershipStatus.ACTIVE, NOW, null));
        memberships.save(new GroupMembershipEntity(UUID.randomUUID(), groupId, admin, GroupRole.ADMIN, GroupMembershipStatus.ACTIVE, NOW, null));
        GroupMembershipEntity memberCMembership = memberships.save(new GroupMembershipEntity(UUID.randomUUID(), groupId, memberC, GroupRole.MEMBER, GroupMembershipStatus.ACTIVE, NOW, null));
        memberships.save(new GroupMembershipEntity(UUID.randomUUID(), groupId, memberD, GroupRole.MEMBER, GroupMembershipStatus.ACTIVE, NOW, null));
        UUID activityId = UUID.randomUUID();
        ActivityEntity activity = activities.save(new ActivityEntity(activityId, groupId, owner, "M8 test", null,
                ActivityStatus.CONFIRMED, null, null, null, null, null, NOW, NOW));
        return new Fixture(groupId, activityId, owner, admin, memberC, memberD, outsider, group, activity, memberCMembership);
    }

    private CreatePollRequest pollRequest(VoteVisibility visibility) {
        return new CreatePollRequest("Choose", PollType.SINGLE_CHOICE, List.of("A", "B"), false, null,
                visibility, ResultVisibility.IMMEDIATE, null);
    }

    @Test
    void publicChatVoteActivitiesAreDurableOrderedNoopAndDelayedRetrySafe() {
        Fixture f=fixture(); UUID conversation=chat.openGroup(f.groupId(),f.owner()).id();
        var original=chat.createPoll(conversation,f.owner(),new com.wedo.backend.chat.dto.ChatRequests.CreatePoll(null,UUID.randomUUID(),pollRequest(VoteVisibility.PUBLIC)));
        var p=polls.get(original.pollId(),f.memberC()); UUID a=p.options().get(0).id(),b=p.options().get(1).id();
        UUID first=UUID.randomUUID(),changed=UUID.randomUUID();
        polls.vote(p.id(),f.memberC(),new VotePollRequest(List.of(a),first));
        polls.vote(p.id(),f.memberC(),new VotePollRequest(List.of(a),first));
        polls.vote(p.id(),f.memberC(),new VotePollRequest(List.of(a),UUID.randomUUID())); // no-op receipt
        polls.vote(p.id(),f.memberC(),new VotePollRequest(List.of(b),changed));
        polls.vote(p.id(),f.memberC(),new VotePollRequest(List.of(a),first)); // delayed old command
        var history=chat.history(conversation,f.owner(),null,30).messages();
        assertEquals(List.of("POLL","POLL_VOTED","POLL_VOTE_CHANGED"),history.stream().map(m->m.type()).toList());
        assertEquals(List.of(1L,2L,3L),history.stream().map(m->m.sequence()).toList());
        assertTrue(history.stream().allMatch(m->m.pollId().equals(p.id())));
        assertEquals(3,history.stream().map(m->m.id()).distinct().count());
        assertEquals(List.of(b),polls.get(p.id(),f.memberC()).callerOptionIds());
        assertEquals(1,polls.get(p.id(),f.owner()).participantCount());
        assertEquals(f.memberC(),polls.get(p.id(),f.owner()).participantPreview().getFirst().id());
        assertTrue(polls.voters(p.id(),f.owner()).stream().flatMap(v->v.participants().stream()).anyMatch(u->u.id().equals(f.memberC())));
        var activity=history.getLast();
        assertFalse(activity.permissions().canEdit()); assertFalse(activity.permissions().canUnsend());
        assertCode(ErrorCode.ACCESS_DENIED,()->chat.unsend(activity.id(),f.memberC()));
    }

    @Test
    void chatVoteRollbackAndRejectedVoteLeaveNoActivityReceiptOrSequence() throws Exception {
        Fixture f=fixture();UUID conversation=chat.openGroup(f.groupId(),f.owner()).id();
        var original=chat.createPoll(conversation,f.owner(),new com.wedo.backend.chat.dto.ChatRequests.CreatePoll(f.activityId(),UUID.randomUUID(),pollRequest(VoteVisibility.PUBLIC)));
        var p=polls.get(original.pollId(),f.owner());UUID command=UUID.randomUUID(); awaitDelivery();
        try(var peer=new com.wedo.backend.realtime.RealtimeProbe(realtime,f.memberD(),"activity:"+f.activityId())) {
            new org.springframework.transaction.support.TransactionTemplate(transactionManager).executeWithoutResult(tx->{
                polls.vote(p.id(),f.memberC(),new VotePollRequest(List.of(p.options().getFirst().id()),command));
                assertTrue(peer.frames.isEmpty());tx.setRollbackOnly();
            });
            awaitDelivery();assertTrue(peer.frames.isEmpty());
        }
        assertThrows(BusinessException.class,()->polls.vote(p.id(),f.memberC(),new VotePollRequest(List.of(UUID.randomUUID()),command)));
        assertThrows(BusinessException.class,()->polls.vote(p.id(),f.outsider(),new VotePollRequest(List.of(p.options().getFirst().id()),command)));
        assertEquals(0,jdbc.queryForObject("SELECT count(*) FROM poll_vote_commands WHERE poll_id=?",Integer.class,p.id()));
        assertEquals(1,chat.history(conversation,f.owner(),null,30).messages().size());
        assertEquals(1L,jdbc.queryForObject("SELECT current_sequence FROM conversation_sequences WHERE conversation_id=?",Long.class,conversation));
        assertEquals(0,polls.get(p.id(),f.owner()).participantCount());
    }

    @Test
    void anonymousChatVoteHasNoTimelineIdentityOrPreviewEvenAfterClose() {
        Fixture f=fixture();UUID conversation=chat.openGroup(f.groupId(),f.owner()).id();
        var original=chat.createPoll(conversation,f.owner(),new com.wedo.backend.chat.dto.ChatRequests.CreatePoll(null,UUID.randomUUID(),pollRequest(VoteVisibility.ANONYMOUS)));
        var p=polls.get(original.pollId(),f.owner());
        polls.vote(p.id(),f.memberC(),new VotePollRequest(List.of(p.options().getFirst().id()),UUID.randomUUID()));
        polls.vote(p.id(),f.memberC(),new VotePollRequest(List.of(p.options().getLast().id()),UUID.randomUUID()));
        assertEquals(1,chat.history(conversation,f.memberD(),null,30).messages().size());
        assertTrue(polls.get(p.id(),f.memberD()).participantPreview().isEmpty());
        assertFalse(polls.get(p.id(),f.memberD()).permissions().canViewVoters());
        polls.close(p.id(),f.owner());
        assertTrue(polls.get(p.id(),f.memberD()).participantPreview().isEmpty());
        assertCode(ErrorCode.POLL_VOTERS_PRIVATE,()->polls.voters(p.id(),f.owner()));
    }

    @Test
    void publicAfterCloseVotersCannotBypassResultVisibilityAndMembership() {
        Fixture f=fixture();var p=polls.createGroup(f.groupId(),f.owner(),new CreatePollRequest("Hidden",PollType.MULTIPLE_CHOICE,List.of("A","B"),false,2,VoteVisibility.PUBLIC,ResultVisibility.AFTER_CLOSE,null));
        polls.vote(p.id(),f.memberC(),new VotePollRequest(p.options().stream().map(o->o.id()).toList()));
        var hidden=polls.get(p.id(),f.memberD()); assertEquals(1,hidden.participantCount());
        assertTrue(hidden.participantPreview().isEmpty());assertFalse(hidden.permissions().canViewVoters());
        assertCode(ErrorCode.POLL_VOTERS_PRIVATE,()->polls.voters(p.id(),f.owner()));
        polls.close(p.id(),f.owner());
        assertEquals(2,polls.voters(p.id(),f.owner()).stream().flatMap(v->v.participants().stream()).count());
        assertEquals(1,polls.get(p.id(),f.owner()).participantCount());
        bans.banMember(f.groupId(),f.memberC(),f.owner(),"isolated privacy fixture");
        assertThrows(BusinessException.class,()->polls.voters(p.id(),f.memberC()));
        assertThrows(BusinessException.class,()->polls.get(p.id(),f.memberC()));
    }

    @Test
    void concurrentPublicVotesAndDuplicateCommandsKeepOneTimelineItemPerChange() throws Exception {
        Fixture f=fixture();UUID conversation=chat.openGroup(f.groupId(),f.owner()).id();
        var original=chat.createPoll(conversation,f.owner(),new com.wedo.backend.chat.dto.ChatRequests.CreatePoll(f.activityId(),UUID.randomUUID(),pollRequest(VoteVisibility.PUBLIC)));
        var p=polls.get(original.pollId(),f.owner());UUID command=UUID.randomUUID();
        try(var pool=java.util.concurrent.Executors.newFixedThreadPool(3)) {
            var jobs=List.of(pool.submit(()->polls.vote(p.id(),f.memberC(),new VotePollRequest(List.of(p.options().getFirst().id()),command))),pool.submit(()->polls.vote(p.id(),f.memberC(),new VotePollRequest(List.of(p.options().getFirst().id()),command))),pool.submit(()->polls.vote(p.id(),f.memberD(),new VotePollRequest(List.of(p.options().getLast().id()),UUID.randomUUID()))));
            for(var job:jobs)job.get(15,java.util.concurrent.TimeUnit.SECONDS);
        }
        assertEquals(2,polls.get(p.id(),f.owner()).participantCount());
        assertEquals(3,chat.history(conversation,f.owner(),null,30).messages().size());
        assertEquals(2,jdbc.queryForObject("SELECT count(*) FROM messages WHERE poll_id=? AND type='POLL_VOTED'",Integer.class,p.id()));
    }

    private void assertCode(ErrorCode expected, Runnable call) {
        assertEquals(expected, assertThrows(BusinessException.class, call::run).errorCode());
    }

    private void assertNotification(UUID recipient, String eventType, String category, String targetType,
                                    UUID targetId, UUID activityId) {
        awaitDelivery();
        assertEquals(1, jdbc.queryForObject("""
                SELECT count(*) FROM notifications
                WHERE user_id = ? AND category = ? AND data->>'eventType' = ?
                  AND data->>'targetType' = ? AND data->>'targetId' = ?
                  AND data->>'activityId' = ?
                """, Integer.class, recipient, category, eventType, targetType, targetId.toString(), activityId.toString()));
        assertNotificationCount(recipient, eventType, targetId, 1);
    }

    private void assertNotificationCount(UUID recipient, String eventType, UUID targetId, int expected) {
        awaitDelivery();
        assertEquals(expected, jdbc.queryForObject("""
                SELECT count(*) FROM notifications
                WHERE user_id = ? AND data->>'eventType' = ? AND data->>'targetId' = ?
                """, Integer.class, recipient, eventType, targetId.toString()));
    }

    private record Persona(UUID id, String name) { }
    private record Fixture(UUID groupId, UUID activityId, UUID owner, UUID admin, UUID memberC, UUID memberD,
            UUID outsider, GroupEntity group, ActivityEntity activity, GroupMembershipEntity memberCMembership) { }
}
