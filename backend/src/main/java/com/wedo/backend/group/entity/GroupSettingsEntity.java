package com.wedo.backend.group.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.Instant;
import java.util.UUID;
import java.util.Objects;

@Entity
@Table(name = "group_settings")
public class GroupSettingsEntity {

    @Id
    @Column(name = "group_id", nullable = false)
    private UUID groupId;

    @Enumerated(EnumType.STRING)
    @Column(name = "join_policy", nullable = false, length = 30)
    private GroupJoinPolicy joinPolicy;

    @Column(name = "member_modify_info_allowed", nullable = false)
    private boolean memberModifyInfoAllowed;

    @Column(name = "member_create_activity_allowed", nullable = false)
    private boolean memberCreateActivityAllowed;

    @Column(name = "member_pin_message_allowed", nullable = false)
    private boolean memberPinMessageAllowed;

    @Enumerated(EnumType.STRING)
    @Column(name = "chat_history_policy", nullable = false, length = 30)
    private ChatHistoryPolicy chatHistoryPolicy;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected GroupSettingsEntity() {
    }

    private GroupSettingsEntity(UUID groupId, GroupJoinPolicy joinPolicy, boolean memberModifyInfoAllowed, boolean memberCreateActivityAllowed, boolean memberPinMessageAllowed, ChatHistoryPolicy chatHistoryPolicy, Instant createdAt, Instant updatedAt) {
        this.groupId = groupId;
        this.joinPolicy = joinPolicy;
        this.memberModifyInfoAllowed = memberModifyInfoAllowed;
        this.memberCreateActivityAllowed = memberCreateActivityAllowed;
        this.memberPinMessageAllowed = memberPinMessageAllowed;
        this.chatHistoryPolicy = chatHistoryPolicy;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
    }

    public static GroupSettingsEntity createDefault(UUID groupId, Instant now) {
        return new GroupSettingsEntity(groupId, GroupJoinPolicy.AUTO_JOIN, false, true, false, ChatHistoryPolicy.FULL_HISTORY, now, now);
    }

    public UUID getGroupId() { return groupId; }
    public GroupJoinPolicy getJoinPolicy() { return joinPolicy; }
    public boolean isMemberModifyInfoAllowed() { return memberModifyInfoAllowed; }
    public boolean isMemberCreateActivityAllowed() { return memberCreateActivityAllowed; }
    public boolean isMemberPinMessageAllowed() { return memberPinMessageAllowed; }
    public ChatHistoryPolicy getChatHistoryPolicy() { return chatHistoryPolicy; }
    public Instant getUpdatedAt() { return updatedAt; }

    public boolean update(
            GroupJoinPolicy joinPolicy,
            boolean memberModifyInfoAllowed,
            boolean memberCreateActivityAllowed,
            boolean memberPinMessageAllowed,
            ChatHistoryPolicy chatHistoryPolicy,
            Instant now
    ) {
        if (this.joinPolicy == joinPolicy
                && this.memberModifyInfoAllowed == memberModifyInfoAllowed
                && this.memberCreateActivityAllowed == memberCreateActivityAllowed
                && this.memberPinMessageAllowed == memberPinMessageAllowed
                && this.chatHistoryPolicy == chatHistoryPolicy) {
            return false;
        }
        this.joinPolicy = Objects.requireNonNull(joinPolicy);
        this.memberModifyInfoAllowed = memberModifyInfoAllowed;
        this.memberCreateActivityAllowed = memberCreateActivityAllowed;
        this.memberPinMessageAllowed = memberPinMessageAllowed;
        this.chatHistoryPolicy = Objects.requireNonNull(chatHistoryPolicy);
        this.updatedAt = now;
        return true;
    }
}
