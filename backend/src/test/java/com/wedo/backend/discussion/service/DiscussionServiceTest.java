package com.wedo.backend.discussion.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.wedo.backend.activity.entity.ActivityEntity;
import com.wedo.backend.activity.entity.ActivityStatus;
import com.wedo.backend.activity.service.M8ActivityAccess;
import com.wedo.backend.activity.service.M8ActivityAccessService;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.discussion.dto.ActivityDiscussionResponse;
import com.wedo.backend.discussion.dto.CreateCommentRequest;
import com.wedo.backend.discussion.entity.ActivityCommentEntity;
import com.wedo.backend.discussion.repository.ActivityCommentRepository;
import com.wedo.backend.group.entity.GroupEntity;
import com.wedo.backend.group.entity.GroupMembershipEntity;
import com.wedo.backend.group.entity.GroupMembershipStatus;
import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.group.repository.GroupActivityLogRepository;
import com.wedo.backend.group.service.ReadableGroupAccess;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserRepository;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class DiscussionServiceTest {
    @Test
    void listProjectsEachCommentAuthorsExistingPublicProfile() {
        UUID activityId = UUID.randomUUID();
        UUID actorId = UUID.randomUUID();
        UUID parentAuthorId = UUID.randomUUID();
        UUID replyAuthorId = UUID.randomUUID();
        M8ActivityAccessService access = mock(M8ActivityAccessService.class);
        ActivityCommentRepository comments = mock(ActivityCommentRepository.class);
        UserRepository users = mock(UserRepository.class);
        when(access.requireReadable(activityId, actorId)).thenReturn(activeAccess(activityId, actorId));
        when(comments.findByActivityIdOrderByCreatedAtAsc(activityId)).thenReturn(List.of(
                comment(activityId, parentAuthorId, null, "Parent"),
                comment(activityId, replyAuthorId, UUID.randomUUID(), "Reply")));
        when(users.findAllById(org.mockito.ArgumentMatchers.any())).thenReturn(List.of(
                user(parentAuthorId, "Lan Nguyen", "avatars/lan.png"),
                user(replyAuthorId, "Minh Tran", null)));

        ActivityDiscussionResponse response = service(access, comments, users).list(activityId, actorId);

        assertEquals("Lan Nguyen", response.comments().get(0).author().displayName());
        assertEquals("avatars/lan.png", response.comments().get(0).author().avatarStorageKey());
        assertEquals("Minh Tran", response.comments().get(1).author().displayName());
        assertTrue(response.comments().get(1).parentCommentId() != null);
    }

    @Test
    void completedActivityIsReadableButRejectsNewComments() {
        assertLocked(ActivityStatus.COMPLETED);
    }

    @Test
    void cancelledActivityIsReadableButRejectsNewComments() {
        assertLocked(ActivityStatus.CANCELLED);
    }

    private void assertLocked(ActivityStatus status) {
        M8ActivityAccessService access = mock(M8ActivityAccessService.class);
        UUID activityId = UUID.randomUUID();
        UUID actor = UUID.randomUUID();
        ActivityEntity activity = new ActivityEntity(activityId, UUID.randomUUID(), UUID.randomUUID(), "A", null,
                status, null, null, null, null, null, Instant.EPOCH, Instant.EPOCH);
        when(access.requireMutable(activityId, actor)).thenReturn(new M8ActivityAccess(activity, null));

        BusinessException exception = assertThrows(BusinessException.class,
                () -> service(access, mock(ActivityCommentRepository.class), mock(UserRepository.class))
                        .create(activityId, actor, new CreateCommentRequest("Hello")));

        assertEquals(ErrorCode.ACTIVITY_CLOSED, exception.errorCode());
    }

    private DiscussionService service(M8ActivityAccessService access, ActivityCommentRepository comments,
            UserRepository users) {
        return new DiscussionService(access, comments, mock(GroupActivityLogRepository.class), users, Clock.systemUTC());
    }

    private M8ActivityAccess activeAccess(UUID activityId, UUID actorId) {
        UUID groupId = UUID.randomUUID();
        GroupEntity group = new GroupEntity(groupId, "Group", null, null, GroupStatus.ACTIVE, actorId, Instant.EPOCH,
                Instant.EPOCH);
        GroupMembershipEntity membership = new GroupMembershipEntity(UUID.randomUUID(), groupId, actorId,
                GroupRole.MEMBER, GroupMembershipStatus.ACTIVE, Instant.EPOCH, null);
        ActivityEntity activity = new ActivityEntity(activityId, groupId, actorId, "Activity", null,
                ActivityStatus.CONFIRMED, null, null, null, null, null, Instant.EPOCH, Instant.EPOCH);
        return new M8ActivityAccess(activity, new ReadableGroupAccess(group, membership));
    }

    private ActivityCommentEntity comment(UUID activityId, UUID authorId, UUID parentCommentId, String content) {
        return new ActivityCommentEntity(UUID.randomUUID(), activityId, authorId, parentCommentId, content, Instant.EPOCH);
    }

    private UserEntity user(UUID id, String displayName, String avatarStorageKey) {
        UserEntity user = new UserEntity(id, id + "@example.com", displayName.toLowerCase().replace(' ', '.'), displayName,
                UserStatus.ACTIVE, Instant.EPOCH, Instant.EPOCH);
        user.setAvatarStorageKey(avatarStorageKey);
        return user;
    }
}
