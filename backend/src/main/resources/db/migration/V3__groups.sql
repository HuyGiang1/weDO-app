-- ============================================================================
-- Migration: V3__groups.sql
-- Module: Groups & Memberships
-- Tables: groups, group_settings, group_memberships, group_invitations, 
--         group_invite_links, group_join_requests, group_bans, group_activity_logs
-- ============================================================================

-- 1. Table: groups
CREATE TABLE groups (
    id UUID PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description VARCHAR(500),
    avatar_storage_key VARCHAR(255),
    status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE'
        CONSTRAINT chk_groups_status CHECK (status IN ('ACTIVE', 'ARCHIVED', 'DELETED')),
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_groups_status ON groups(status);
CREATE INDEX idx_groups_created_by ON groups(created_by);

-- 2. Table: group_settings
CREATE TABLE group_settings (
    group_id UUID PRIMARY KEY REFERENCES groups(id) ON DELETE CASCADE,
    join_policy VARCHAR(30) NOT NULL DEFAULT 'AUTO_JOIN'
        CONSTRAINT chk_group_settings_join_policy CHECK (join_policy IN ('AUTO_JOIN', 'APPROVAL_REQUIRED')),
    member_modify_info_allowed BOOLEAN NOT NULL DEFAULT FALSE,
    member_create_activity_allowed BOOLEAN NOT NULL DEFAULT TRUE,
    member_pin_message_allowed BOOLEAN NOT NULL DEFAULT FALSE,
    chat_history_policy VARCHAR(30) NOT NULL DEFAULT 'FULL_HISTORY'
        CONSTRAINT chk_group_settings_history_policy CHECK (chat_history_policy IN ('FULL_HISTORY', 'FROM_JOIN_TIME')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 3. Table: group_memberships
CREATE TABLE group_memberships (
    id UUID PRIMARY KEY,
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE RESTRICT,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    role VARCHAR(30) NOT NULL DEFAULT 'MEMBER'
        CONSTRAINT chk_group_memberships_role CHECK (role IN ('OWNER', 'ADMIN', 'MEMBER')),
    status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE'
        CONSTRAINT chk_group_memberships_status CHECK (status IN ('ACTIVE', 'LEFT', 'KICKED', 'BANNED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMPTZ,
    CONSTRAINT chk_group_memberships_end_time CHECK (
        (status = 'ACTIVE' AND ended_at IS NULL)
        OR
        (status <> 'ACTIVE' AND ended_at IS NOT NULL)
    )
);

-- Mỗi user chỉ có tối đa 1 active membership trong 1 group, bảo toàn lịch sử các lần tham gia cũ
CREATE UNIQUE INDEX uq_group_memberships_active_user 
    ON group_memberships (group_id, user_id) 
    WHERE status = 'ACTIVE';

-- Đảm bảo chỉ có tối đa 1 ACTIVE OWNER cho mỗi group
CREATE UNIQUE INDEX uq_group_memberships_active_owner 
    ON group_memberships (group_id) 
    WHERE role = 'OWNER' AND status = 'ACTIVE';

CREATE INDEX idx_group_memberships_group_status ON group_memberships(group_id, status);
CREATE INDEX idx_group_memberships_user_status ON group_memberships(user_id, status);

-- 4. Table: group_invitations
CREATE TABLE group_invitations (
    id UUID PRIMARY KEY,
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    inviter_id UUID REFERENCES users(id) ON DELETE SET NULL,
    invitee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING'
        CONSTRAINT chk_group_invitations_status CHECK (status IN ('PENDING', 'ACCEPTED', 'DECLINED', 'CANCELLED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    responded_at TIMESTAMPTZ,
    CONSTRAINT chk_group_invitations_not_self CHECK (inviter_id IS NULL OR inviter_id != invitee_id),
    CONSTRAINT chk_group_invitations_response_time CHECK (
        (status = 'PENDING' AND responded_at IS NULL)
        OR
        (status <> 'PENDING' AND responded_at IS NOT NULL)
    )
);

-- Chống spam gửi nhiều lời mời PENDING cho cùng 1 user trong 1 group
CREATE UNIQUE INDEX uq_group_invitations_pending 
    ON group_invitations (group_id, invitee_id) 
    WHERE status = 'PENDING';

CREATE INDEX idx_group_invitations_invitee_status ON group_invitations(invitee_id, status);
CREATE INDEX idx_group_invitations_group_status ON group_invitations(group_id, status);

-- 5. Table: group_invite_links
CREATE TABLE group_invite_links (
    id UUID PRIMARY KEY,
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    code VARCHAR(50) NOT NULL UNIQUE,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    max_uses INT,
    uses_count INT NOT NULL DEFAULT 0,
    expires_at TIMESTAMPTZ,
    is_revoked BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_group_invite_links_uses_count CHECK (uses_count >= 0),
    CONSTRAINT chk_group_invite_links_max_uses CHECK (max_uses IS NULL OR max_uses > 0),
    CONSTRAINT chk_group_invite_links_usage_limit CHECK (max_uses IS NULL OR uses_count <= max_uses)
);

CREATE INDEX idx_group_invite_links_group_active ON group_invite_links(group_id, is_revoked);

-- 6. Table: group_join_requests
CREATE TABLE group_join_requests (
    id UUID PRIMARY KEY,
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING'
        CONSTRAINT chk_group_join_requests_status CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    responded_at TIMESTAMPTZ,
    responded_by UUID REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT chk_group_join_requests_consistency CHECK (
        (status = 'PENDING' AND responded_at IS NULL AND responded_by IS NULL)
        OR
        (status IN ('APPROVED', 'REJECTED') AND responded_at IS NOT NULL)
        OR
        (status = 'CANCELLED' AND responded_at IS NOT NULL AND responded_by IS NULL)
    )
);

-- Chống spam: Mỗi user chỉ có tối đa 1 yêu cầu gia nhập PENDING trong 1 group
CREATE UNIQUE INDEX uq_group_join_requests_pending 
    ON group_join_requests (group_id, user_id) 
    WHERE status = 'PENDING';

CREATE INDEX idx_group_join_requests_group_status ON group_join_requests(group_id, status);
CREATE INDEX idx_group_join_requests_user_status ON group_join_requests(user_id, status);

-- 7. Table: group_bans
CREATE TABLE group_bans (
    id UUID PRIMARY KEY,
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    banned_by UUID REFERENCES users(id) ON DELETE SET NULL,
    reason VARCHAR(500),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    unbanned_at TIMESTAMPTZ,
    CONSTRAINT chk_group_bans_not_self CHECK (banned_by IS NULL OR banned_by != user_id)
);

-- Tối đa 1 lệnh cấm đang có hiệu lực (unbanned_at IS NULL) cho mỗi user trong 1 group, bảo toàn lịch sử các lần cấm trước
CREATE UNIQUE INDEX uq_group_bans_active 
    ON group_bans (group_id, user_id) 
    WHERE unbanned_at IS NULL;

-- 8. Table: group_activity_logs
CREATE TABLE group_activity_logs (
    id UUID PRIMARY KEY,
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    actor_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(50) NOT NULL,
    target_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_group_activity_logs_group_created ON group_activity_logs(group_id, created_at DESC);
