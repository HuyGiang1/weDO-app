-- ============================================================================
-- Migration: V9__notifications.sql
-- Module: Notification Center, User Push Settings, Group Mute, and Activity Reminders
-- Note: user_devices was already created in V1__identity_and_auth.sql
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Table: notifications (In-app user notification inbox)
-- ----------------------------------------------------------------------------
CREATE TABLE notifications (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    actor_id UUID REFERENCES users(id) ON DELETE SET NULL,
    group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
    category VARCHAR(20) NOT NULL
        CONSTRAINT chk_notifications_category CHECK (
            category IN ('SOCIAL', 'GROUP', 'CHAT', 'ACTIVITY', 'POLL', 'TASK', 'FINANCE', 'FUND')
        ),
    priority VARCHAR(10) NOT NULL DEFAULT 'NORMAL'
        CONSTRAINT chk_notifications_priority CHECK (priority IN ('HIGH', 'NORMAL', 'LOW')),
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    data JSONB,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_notifications_title_non_empty CHECK (length(trim(title)) > 0),
    CONSTRAINT chk_notifications_body_non_empty CHECK (length(trim(body)) > 0)
);

CREATE INDEX idx_notifications_user_created ON notifications(user_id, created_at DESC);
CREATE INDEX idx_notifications_user_unread ON notifications(user_id, created_at DESC) WHERE read_at IS NULL;
CREATE INDEX idx_notifications_group ON notifications(group_id) WHERE group_id IS NOT NULL;

-- ----------------------------------------------------------------------------
-- 2. Table: user_notification_settings (Per-user category push preferences)
-- ----------------------------------------------------------------------------
CREATE TABLE user_notification_settings (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    push_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    social_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    group_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    chat_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    activity_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    poll_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    task_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    finance_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    fund_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ----------------------------------------------------------------------------
-- 3. Table: group_notification_settings (Group-level mute overrides)
-- ----------------------------------------------------------------------------
CREATE TABLE group_notification_settings (
    id UUID PRIMARY KEY,
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    muted BOOLEAN NOT NULL DEFAULT FALSE,
    muted_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_group_notification_settings_user_group UNIQUE (user_id, group_id),
    CONSTRAINT chk_group_notif_muted_consistency CHECK (
        (muted = FALSE AND muted_until IS NULL)
        OR
        (muted = TRUE)
    )
);

-- ----------------------------------------------------------------------------
-- 4. Table: user_activity_reminders (Single personal reminder per user per activity)
-- ----------------------------------------------------------------------------
CREATE TABLE user_activity_reminders (
    id UUID PRIMARY KEY,
    activity_id UUID NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    offset_minutes INT NOT NULL
        CONSTRAINT chk_reminders_offset CHECK (offset_minutes > 0),
    remind_at TIMESTAMPTZ NOT NULL,
    sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_user_activity_reminders UNIQUE (activity_id, user_id)
);

CREATE INDEX idx_user_activity_reminders_due ON user_activity_reminders(remind_at) WHERE enabled = TRUE AND sent_at IS NULL;
CREATE INDEX idx_user_activity_reminders_user ON user_activity_reminders(user_id);
