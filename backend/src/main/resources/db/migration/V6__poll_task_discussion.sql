-- ============================================================================
-- Migration: V6__poll_task_discussion.sql
-- Module: Poll, Task & Activity Discussion
-- Tables: polls, poll_options, poll_votes, poll_vote_choices,
--         tasks, task_assignees, task_status_history, activity_comments
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Table: polls
-- ----------------------------------------------------------------------------
CREATE TABLE polls (
    id UUID PRIMARY KEY,
    activity_id UUID NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    question VARCHAR(255) NOT NULL,
    poll_type VARCHAR(20) NOT NULL DEFAULT 'SINGLE_CHOICE'
        CONSTRAINT chk_polls_type CHECK (poll_type IN ('SINGLE_CHOICE', 'MULTIPLE_CHOICE')),
    allow_member_add_option BOOLEAN NOT NULL DEFAULT FALSE,
    max_selections INT,
    vote_visibility VARCHAR(20) NOT NULL DEFAULT 'PUBLIC'
        CONSTRAINT chk_polls_vote_visibility CHECK (vote_visibility IN ('PUBLIC', 'ANONYMOUS')),
    result_visibility VARCHAR(20) NOT NULL DEFAULT 'IMMEDIATE'
        CONSTRAINT chk_polls_result_visibility CHECK (result_visibility IN ('IMMEDIATE', 'AFTER_CLOSE')),
    status VARCHAR(20) NOT NULL DEFAULT 'OPEN'
        CONSTRAINT chk_polls_status CHECK (status IN ('OPEN', 'CLOSED')),
    deadline_at TIMESTAMPTZ,
    closed_at TIMESTAMPTZ,
    closed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_polls_question_non_empty CHECK (length(trim(question)) > 0),
    CONSTRAINT chk_polls_max_selections_consistency CHECK (
        (poll_type = 'SINGLE_CHOICE' AND max_selections IS NULL)
        OR
        (poll_type = 'MULTIPLE_CHOICE' AND (max_selections IS NULL OR max_selections >= 1))
    ),
    CONSTRAINT chk_polls_closed_consistency CHECK (
        (status = 'OPEN' AND closed_at IS NULL AND closed_by IS NULL)
        OR
        (status = 'CLOSED' AND closed_at IS NOT NULL)
    )
);

CREATE INDEX idx_polls_activity_created_at ON polls(activity_id, created_at DESC);

-- ----------------------------------------------------------------------------
-- 2. Table: poll_options
-- ----------------------------------------------------------------------------
CREATE TABLE poll_options (
    id UUID PRIMARY KEY,
    poll_id UUID NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
    text VARCHAR(255) NOT NULL,
    sort_order INT NOT NULL DEFAULT 0
        CONSTRAINT chk_poll_options_sort_order CHECK (sort_order >= 0),
    is_disabled BOOLEAN NOT NULL DEFAULT FALSE,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_poll_options_text_non_empty CHECK (length(trim(text)) > 0),
    CONSTRAINT uq_poll_options_poll_sort UNIQUE (poll_id, sort_order),
    CONSTRAINT uq_poll_options_poll_text UNIQUE (poll_id, text)
);

-- ----------------------------------------------------------------------------
-- 3. Table: poll_votes (One active ballot per user per poll)
-- ----------------------------------------------------------------------------
CREATE TABLE poll_votes (
    id UUID PRIMARY KEY,
    poll_id UUID NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_poll_votes_poll_user UNIQUE (poll_id, user_id)
);

CREATE INDEX idx_poll_votes_user ON poll_votes(user_id);

-- ----------------------------------------------------------------------------
-- 4. Table: poll_vote_choices
-- ----------------------------------------------------------------------------
CREATE TABLE poll_vote_choices (
    id UUID PRIMARY KEY,
    vote_id UUID NOT NULL REFERENCES poll_votes(id) ON DELETE CASCADE,
    option_id UUID NOT NULL REFERENCES poll_options(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_poll_vote_choices_vote_option UNIQUE (vote_id, option_id)
);

CREATE INDEX idx_poll_vote_choices_option ON poll_vote_choices(option_id);

-- ----------------------------------------------------------------------------
-- 5. Table: tasks
-- ----------------------------------------------------------------------------
CREATE TABLE tasks (
    id UUID PRIMARY KEY,
    activity_id UUID NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'TODO'
        CONSTRAINT chk_tasks_status CHECK (status IN ('TODO', 'IN_PROGRESS', 'DONE')),
    due_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_tasks_title_non_empty CHECK (length(trim(title)) > 0)
);

CREATE INDEX idx_tasks_activity_status ON tasks(activity_id, status);
CREATE INDEX idx_tasks_due_at ON tasks(due_at) WHERE due_at IS NOT NULL;

-- ----------------------------------------------------------------------------
-- 6. Table: task_assignees (One or many assignees per task)
-- ----------------------------------------------------------------------------
CREATE TABLE task_assignees (
    id UUID PRIMARY KEY,
    task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    assigned_by UUID REFERENCES users(id) ON DELETE SET NULL,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_task_assignees_task_user UNIQUE (task_id, user_id)
);

CREATE INDEX idx_task_assignees_user ON task_assignees(user_id);

-- ----------------------------------------------------------------------------
-- 7. Table: task_status_history (Audit status transitions)
-- ----------------------------------------------------------------------------
CREATE TABLE task_status_history (
    id UUID PRIMARY KEY,
    task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    from_status VARCHAR(20)
        CONSTRAINT chk_task_status_history_from CHECK (from_status IS NULL OR from_status IN ('TODO', 'IN_PROGRESS', 'DONE')),
    to_status VARCHAR(20) NOT NULL
        CONSTRAINT chk_task_status_history_to CHECK (to_status IN ('TODO', 'IN_PROGRESS', 'DONE')),
    changed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_task_status_history_task_created ON task_status_history(task_id, created_at ASC);

-- ----------------------------------------------------------------------------
-- 8. Table: activity_comments (Discussion forum with 1-level replies & soft delete)
-- ----------------------------------------------------------------------------
CREATE TABLE activity_comments (
    id UUID PRIMARY KEY,
    activity_id UUID NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    parent_comment_id UUID REFERENCES activity_comments(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    is_edited BOOLEAN NOT NULL DEFAULT FALSE,
    edited_at TIMESTAMPTZ,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_activity_comments_content_non_empty CHECK (length(trim(content)) > 0),
    CONSTRAINT chk_activity_comments_edit_consistency CHECK (
        (is_edited = FALSE AND edited_at IS NULL)
        OR
        (is_edited = TRUE AND edited_at IS NOT NULL)
    ),
    CONSTRAINT chk_activity_comments_delete_consistency CHECK (
        (is_deleted = FALSE AND deleted_at IS NULL AND deleted_by IS NULL)
        OR
        (is_deleted = TRUE AND deleted_at IS NOT NULL)
    )
);

CREATE INDEX idx_activity_comments_activity_created ON activity_comments(activity_id, created_at ASC);
CREATE INDEX idx_activity_comments_parent ON activity_comments(parent_comment_id) WHERE parent_comment_id IS NOT NULL;
