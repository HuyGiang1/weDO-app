package com.wedo.backend.realtime;

import com.wedo.backend.chat.service.ChatService;
import com.wedo.backend.group.service.GroupPermissionService;
import com.wedo.backend.activity.service.M8ActivityAccessService;
import com.wedo.backend.user.service.UserService;
import java.util.UUID;
import org.springframework.stereotype.Component;

@Component
public class RealtimeScopeAccess {
    @org.springframework.beans.factory.annotation.Autowired(required=false)
    private com.wedo.backend.community.ModerationService moderation;
    @org.springframework.beans.factory.annotation.Autowired(required=false)
    private com.wedo.backend.community.CommunityAccess community;
    @org.springframework.beans.factory.annotation.Autowired(required=false)
    private com.wedo.backend.community.RecruitmentProjection recruitment;
    private final GroupPermissionService groups;
    private final M8ActivityAccessService activities;
    private final ChatService chat;
    private final UserService users;

    public RealtimeScopeAccess(GroupPermissionService groups, M8ActivityAccessService activities,
            ChatService chat, UserService users) {
        this.groups = groups; this.activities = activities; this.chat = chat; this.users = users;
    }

    public boolean allowed(String scope, UUID userId) {
        try {
            if (scope == null || scope.length() > 64) return false;
            String[] parts = scope.split(":", -1);
            if (parts.length != 2) return false;
            UUID id = UUID.fromString(parts[1]);
            if (!scope.equals(parts[0] + ":" + id)) return false;
            users.requireActiveUser(userId);
            return switch (parts[0]) {
                case "moderation" -> id.equals(userId) && moderation!=null && moderation.capabilities(userId).canReview();
                case "community" -> id.equals(userId);
                case "post" -> community != null && community.canRead(id,userId);
                case "review" -> community != null && recruitment != null && community.canRead(id,userId)
                    && recruitment.view(id,userId)!=null && recruitment.view(id,userId).canManage();
                case "user" -> id.equals(userId);
                case "group" -> { groups.requireReadableMembership(id, userId); yield true; }
                case "activity" -> { activities.requireReadable(id, userId); yield true; }
                case "conversation" -> chat.canSubscribeConversation(id, userId);
                default -> false;
            };
        } catch (RuntimeException denied) { return false; }
    }

    public UUID groupForScope(String scope, UUID userId) {
        String[] parts = scope.split(":", -1);
        if (parts.length != 2) return null;
        if (parts[0].equals("group")) return UUID.fromString(parts[1]);
        if (parts[0].equals("activity")) {
            return activities.requireReadable(UUID.fromString(parts[1]), userId).activity().getGroupId();
        }
        return null;
    }

    public boolean canViewJoinRequests(UUID groupId, UUID userId) {
        try {
            var role = groups.requireReadableMembership(groupId, userId).membership().getRole();
            return role == com.wedo.backend.group.entity.GroupRole.OWNER
                    || role == com.wedo.backend.group.entity.GroupRole.ADMIN;
        } catch (RuntimeException denied) { return false; }
    }

    public boolean canViewModerationReport(UUID reportId,UUID userId) {
        return moderation!=null && moderation.canReadReport(reportId,userId);
    }
}
