package com.wedo.backend.m8;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.wedo.backend.activity.entity.ActivityEntity;
import com.wedo.backend.activity.entity.ActivityStatus;
import com.wedo.backend.activity.repository.ActivityRepository;
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

/**
 * Deterministic real-PostgreSQL M8 persona coverage.
 * Run with: .\mvnw.cmd -Dtest=M8MultiAccountIntegrationTest test
 */
class M8MultiAccountIntegrationTest extends AbstractPostgresIntegrationTest {
    private static final Instant NOW = Instant.parse("2026-09-26T00:00:00Z");

    @Autowired private UserRepository users;
    @Autowired private GroupRepository groups;
    @Autowired private GroupMembershipRepository memberships;
    @Autowired private ActivityRepository activities;
    @Autowired private TaskRepository tasks;
    @Autowired private PollService polls;
    @Autowired private TaskService taskService;
    @Autowired private DiscussionService discussions;
    @Autowired private GroupBanService bans;

    @Test
    void pollPersonasCoverVotingClosureAnonymityAndOutsiderProtection() {
        Fixture fixture = fixture();
        PollResponse publicPoll = polls.create(fixture.activityId, fixture.owner(), pollRequest(VoteVisibility.PUBLIC));
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
        assertCode(ErrorCode.POLL_CLOSED,
                () -> polls.vote(publicPoll.id(), fixture.memberC(), new VotePollRequest(List.of(optionA))));

        PollResponse anonymousPoll = polls.create(fixture.activityId, fixture.owner(), pollRequest(VoteVisibility.ANONYMOUS));
        polls.vote(anonymousPoll.id(), fixture.memberC(), new VotePollRequest(List.of(anonymousPoll.options().get(0).id())));
        assertCode(ErrorCode.POLL_VOTERS_PRIVATE, () -> polls.voters(anonymousPoll.id(), fixture.owner()));
    }

    @Test
    void taskPersonasCoverAssignmentStatusClaimDeletionAndOutsiderProtection() {
        Fixture fixture = fixture();
        TaskResponse assigned = taskService.create(fixture.activityId, fixture.owner(),
                new CreateTaskRequest("Assigned", null, List.of(fixture.memberC()), null));
        assertTrue(taskService.get(assigned.id(), fixture.owner()).permissions().canDelete());
        assertFalse(taskService.get(assigned.id(), fixture.memberC()).permissions().canDelete());
        assertTrue(taskService.get(assigned.id(), fixture.memberC()).permissions().canChangeStatus());
        taskService.changeStatus(assigned.id(), fixture.memberC(), new UpdateTaskStatusRequest(TaskStatus.IN_PROGRESS));
        assertCode(ErrorCode.TASK_UPDATE_NOT_ALLOWED,
                () -> taskService.changeStatus(assigned.id(), fixture.memberD(), new UpdateTaskStatusRequest(TaskStatus.DONE)));
        TaskResponse adminUpdated = taskService.update(assigned.id(), fixture.admin(),
                new UpdateTaskRequest("Admin updated", null, null, List.of(fixture.memberC())));
        assertTrue(adminUpdated.permissions().canManageAssignees());

        TaskResponse claimable = taskService.create(fixture.activityId, fixture.owner(),
                new CreateTaskRequest("Claimable", null, List.of(), null));
        assertTrue(taskService.get(claimable.id(), fixture.memberD()).permissions().canClaim());
        assertEquals(List.of(fixture.memberD()), taskService.claim(claimable.id(), fixture.memberD()).assigneeUserIds());
        assertCode(ErrorCode.GROUP_NOT_FOUND, () -> taskService.claim(claimable.id(), fixture.outsider()));

        taskService.delete(assigned.id(), fixture.owner());
        assertFalse(tasks.existsById(assigned.id()));
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

    private void assertCode(ErrorCode expected, Runnable call) {
        assertEquals(expected, assertThrows(BusinessException.class, call::run).errorCode());
    }

    private record Persona(UUID id, String name) { }
    private record Fixture(UUID groupId, UUID activityId, UUID owner, UUID admin, UUID memberC, UUID memberD,
            UUID outsider, GroupEntity group, ActivityEntity activity, GroupMembershipEntity memberCMembership) { }
}
