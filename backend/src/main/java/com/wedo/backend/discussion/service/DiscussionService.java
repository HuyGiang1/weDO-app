package com.wedo.backend.discussion.service;
import com.wedo.backend.activity.entity.ActivityStatus;
import com.wedo.backend.activity.service.M8ActivityAccess;
import com.wedo.backend.activity.service.M8ActivityAccessService;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.discussion.dto.ActivityDiscussionResponse;
import com.wedo.backend.discussion.dto.CommentPermissions;
import com.wedo.backend.discussion.dto.CommentResponse;
import com.wedo.backend.discussion.dto.CreateCommentRequest;
import com.wedo.backend.discussion.dto.DiscussionPermissions;
import com.wedo.backend.discussion.dto.UpdateCommentRequest;
import com.wedo.backend.discussion.entity.ActivityCommentEntity;
import com.wedo.backend.discussion.repository.ActivityCommentRepository;
import com.wedo.backend.group.entity.GroupActivityAction;
import com.wedo.backend.group.entity.GroupActivityLogEntity;
import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.group.repository.GroupActivityLogRepository;
import com.wedo.backend.user.dto.UserPublicProfileResponse;
import com.wedo.backend.user.repository.UserRepository;
import java.time.Clock;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class DiscussionService {
    private final M8ActivityAccessService access;
    private final ActivityCommentRepository comments;
    private final GroupActivityLogRepository logs;
    private final UserRepository users;
    private final Clock clock;

    public DiscussionService(M8ActivityAccessService access, ActivityCommentRepository comments,
            GroupActivityLogRepository logs, UserRepository users, Clock clock) {
        this.access = access;
        this.comments = comments;
        this.logs = logs;
        this.users = users;
        this.clock = clock;
    }

    public ActivityDiscussionResponse list(UUID activityId, UUID actor) {
        M8ActivityAccess activityAccess = access.requireReadable(activityId, actor);
        DiscussionPermissions permissions = state(activityAccess);
        List<ActivityCommentEntity> activityComments = comments.findByActivityIdOrderByCreatedAtAsc(activityId);
        Map<UUID, UserPublicProfileResponse> authors = authorsFor(activityComments);
        return new ActivityDiscussionResponse(permissions, activityComments.stream()
                .map(comment -> response(comment, activityAccess, actor, authors.get(comment.getAuthorId())))
                .toList());
    }

    @Transactional
    public CommentResponse create(UUID activityId, UUID actor, CreateCommentRequest request) {
        M8ActivityAccess activityAccess = mutable(activityId, actor);
        ActivityCommentEntity comment = comments.save(new ActivityCommentEntity(
                UUID.randomUUID(), activityId, actor, null, request.content().trim(), clock.instant()));
        return response(comment, activityAccess, actor, authorFor(actor));
    }

    @Transactional
    public CommentResponse reply(UUID parentId, UUID actor, CreateCommentRequest request) {
        ActivityCommentEntity parent = find(parentId);
        M8ActivityAccess activityAccess = mutable(parent.getActivityId(), actor);
        if (parent.getParentCommentId() != null) throw new BusinessException(ErrorCode.COMMENT_REPLY_DEPTH_EXCEEDED);
        if (parent.isDeleted()) throw new BusinessException(ErrorCode.COMMENT_UPDATE_NOT_ALLOWED);
        ActivityCommentEntity reply = comments.save(new ActivityCommentEntity(
                UUID.randomUUID(), parent.getActivityId(), actor, parentId, request.content().trim(), clock.instant()));
        return response(reply, activityAccess, actor, authorFor(actor));
    }

    @Transactional
    public CommentResponse update(UUID id, UUID actor, UpdateCommentRequest request) {
        ActivityCommentEntity comment = find(id);
        M8ActivityAccess activityAccess = mutable(comment.getActivityId(), actor);
        if (!actor.equals(comment.getAuthorId()) || comment.isDeleted()) {
            throw new BusinessException(ErrorCode.COMMENT_UPDATE_NOT_ALLOWED);
        }
        comment.edit(request.content().trim(), clock.instant());
        return response(comment, activityAccess, actor, authorFor(comment.getAuthorId()));
    }

    @Transactional
    public void delete(UUID id, UUID actor) {
        ActivityCommentEntity comment = find(id);
        M8ActivityAccess activityAccess = mutable(comment.getActivityId(), actor);
        boolean moderator = manager(activityAccess, actor);
        if (!actor.equals(comment.getAuthorId()) && !moderator) {
            throw new BusinessException(ErrorCode.COMMENT_UPDATE_NOT_ALLOWED);
        }
        if (!comment.isDeleted()) {
            Instant now = clock.instant();
            comment.delete(actor, now);
            if (moderator && !actor.equals(comment.getAuthorId())) {
                logs.save(new GroupActivityLogEntity(UUID.randomUUID(), activityAccess.activity().getGroupId(), actor,
                        GroupActivityAction.ACTIVITY_COMMENT_MODERATED, comment.getAuthorId(), now));
            }
        }
    }

    private Map<UUID, UserPublicProfileResponse> authorsFor(Collection<ActivityCommentEntity> activityComments) {
        return users.findAllById(activityComments.stream().map(ActivityCommentEntity::getAuthorId).distinct().toList())
                .stream()
                .map(UserPublicProfileResponse::from)
                .collect(Collectors.toMap(UserPublicProfileResponse::id, Function.identity()));
    }

    private UserPublicProfileResponse authorFor(UUID authorId) {
        return users.findById(authorId).map(UserPublicProfileResponse::from).orElse(null);
    }

    private DiscussionPermissions state(M8ActivityAccess activityAccess) {
        boolean readOnly = activityAccess.groupAccess().group().getStatus() == GroupStatus.ARCHIVED
                || activityAccess.activity().getStatus() == ActivityStatus.COMPLETED
                || activityAccess.activity().getStatus() == ActivityStatus.CANCELLED;
        return new DiscussionPermissions(!readOnly, !readOnly, readOnly);
    }

    private CommentResponse response(ActivityCommentEntity comment, M8ActivityAccess activityAccess, UUID actor,
            UserPublicProfileResponse author) {
        DiscussionPermissions permissions = state(activityAccess);
        boolean moderator = manager(activityAccess, actor);
        boolean owner = actor.equals(comment.getAuthorId()) && !comment.isDeleted();
        return new CommentResponse(comment.getId(), comment.getActivityId(), comment.getAuthorId(), author,
                comment.getParentCommentId(), comment.getContent(), comment.isEdited(), comment.getEditedAt(),
                comment.isDeleted(), comment.getDeletedAt(), comment.getDeletedBy(), comment.getCreatedAt(),
                new CommentPermissions(permissions.canComment(),
                        permissions.canReply() && comment.getParentCommentId() == null,
                        permissions.canComment() && owner, permissions.canComment() && (owner || moderator),
                        permissions.canComment() && moderator, permissions.readOnly()));
    }

    private ActivityCommentEntity find(UUID id) {
        return comments.findById(id).orElseThrow(() -> new BusinessException(ErrorCode.COMMENT_NOT_FOUND));
    }

    private M8ActivityAccess mutable(UUID activityId, UUID actor) {
        M8ActivityAccess activityAccess = access.requireMutable(activityId, actor);
        if (activityAccess.activity().getStatus() == ActivityStatus.COMPLETED
                || activityAccess.activity().getStatus() == ActivityStatus.CANCELLED) {
            throw new BusinessException(ErrorCode.ACTIVITY_CLOSED);
        }
        return activityAccess;
    }

    private boolean manager(M8ActivityAccess activityAccess, UUID actor) {
        GroupRole role = activityAccess.groupAccess().membership().getRole();
        return role == GroupRole.OWNER || role == GroupRole.ADMIN;
    }
}
