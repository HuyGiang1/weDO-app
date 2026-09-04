-- ============================================================================
-- Migration: V5__activities.sql
-- Module: Activity & RSVP
-- Tables: activities, activity_participants, activity_rsvp_history, 
--         activity_waitlist_sequences, activity_status_history, activity_change_logs
-- ============================================================================

-- 1. Table: activities
CREATE TABLE activities (
    id UUID PRIMARY KEY,
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE RESTRICT,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'PLANNING'
        CONSTRAINT chk_activities_status CHECK (status IN ('PLANNING', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED')),
    start_at TIMESTAMPTZ NOT NULL,
    end_at TIMESTAMPTZ,
    timezone VARCHAR(50) NOT NULL,
    location JSONB,
    capacity INT
        CONSTRAINT chk_activities_capacity CHECK (capacity IS NULL OR capacity > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_activities_time_order CHECK (end_at IS NULL OR end_at > start_at)
);

CREATE INDEX idx_activities_group_start ON activities(group_id, start_at);
CREATE INDEX idx_activities_group_status ON activities(group_id, status);

-- 2. Table: activity_waitlist_sequences
CREATE TABLE activity_waitlist_sequences (
    activity_id UUID PRIMARY KEY REFERENCES activities(id) ON DELETE CASCADE,
    current_sequence BIGINT NOT NULL DEFAULT 0
        CONSTRAINT chk_activity_waitlist_sequences_non_negative CHECK (current_sequence >= 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 3. Table: activity_participants
CREATE TABLE activity_participants (
    id UUID PRIMARY KEY,
    activity_id UUID NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    rsvp_status VARCHAR(20) NOT NULL DEFAULT 'NO_RESPONSE'
        CONSTRAINT chk_activity_participants_status CHECK (rsvp_status IN ('NO_RESPONSE', 'GOING', 'MAYBE', 'NOT_GOING', 'WAITLIST')),
    waitlist_sequence BIGINT
        CONSTRAINT chk_activity_participants_waitlist_seq CHECK (waitlist_sequence IS NULL OR waitlist_sequence > 0),
    status_updated_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_activity_participants_user UNIQUE (activity_id, user_id),
    CONSTRAINT chk_activity_participants_waitlist CHECK (
        (rsvp_status = 'WAITLIST' AND waitlist_sequence IS NOT NULL)
        OR
        (rsvp_status <> 'WAITLIST' AND waitlist_sequence IS NULL)
    ),
    CONSTRAINT chk_activity_participants_status_updated CHECK (
        (rsvp_status = 'NO_RESPONSE' AND status_updated_at IS NULL)
        OR
        (rsvp_status <> 'NO_RESPONSE' AND status_updated_at IS NOT NULL)
    )
);

CREATE UNIQUE INDEX uq_activity_participants_waitlist_sequence
    ON activity_participants (activity_id, waitlist_sequence)
    WHERE rsvp_status = 'WAITLIST';

CREATE INDEX idx_activity_participants_activity_status ON activity_participants(activity_id, rsvp_status);
CREATE INDEX idx_activity_participants_user ON activity_participants(user_id, rsvp_status);

-- 4. Table: activity_rsvp_history
CREATE TABLE activity_rsvp_history (
    id UUID PRIMARY KEY,
    activity_id UUID NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    from_status VARCHAR(20)
        CONSTRAINT chk_activity_rsvp_history_from CHECK (from_status IS NULL OR from_status IN ('NO_RESPONSE', 'GOING', 'MAYBE', 'NOT_GOING', 'WAITLIST')),
    to_status VARCHAR(20) NOT NULL
        CONSTRAINT chk_activity_rsvp_history_to CHECK (to_status IN ('NO_RESPONSE', 'GOING', 'MAYBE', 'NOT_GOING', 'WAITLIST')),
    changed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_activity_rsvp_history_activity ON activity_rsvp_history(activity_id, created_at DESC);

-- 5. Table: activity_status_history
CREATE TABLE activity_status_history (
    id UUID PRIMARY KEY,
    activity_id UUID NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
    from_status VARCHAR(20)
        CONSTRAINT chk_activity_status_history_from CHECK (from_status IS NULL OR from_status IN ('PLANNING', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED')),
    to_status VARCHAR(20) NOT NULL
        CONSTRAINT chk_activity_status_history_to CHECK (to_status IN ('PLANNING', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED')),
    changed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    reason VARCHAR(500),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_activity_status_history_activity ON activity_status_history(activity_id, created_at DESC);

-- 6. Table: activity_change_logs
CREATE TABLE activity_change_logs (
    id UUID PRIMARY KEY,
    activity_id UUID NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
    actor_id UUID REFERENCES users(id) ON DELETE SET NULL,
    field_name VARCHAR(50) NOT NULL,
    old_value TEXT,
    new_value TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_activity_change_logs_activity ON activity_change_logs(activity_id, created_at DESC);
